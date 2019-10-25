Queue                                                    = require "p-queue"
config                                                   = require "config"
debug                                                    = (require "debug") "app:AppUpdater"
{ createGroupsMixin, getAppsToChange }                   = require "@viriciti/app-layer-logic"
{ isEmpty, pickBy, first, debounce, map, omit, partial } = require "lodash"
kleur                                                    = require "kleur"

log               = (require "../lib/Logger") "AppUpdater"
removeRecursively = require "../lib/removeRecursively"
firstKey          = require "../helpers/firstKey"

class AppUpdater
	constructor: (@docker, @state, @groupManager) ->
		@handleCollection = debounce @handleCollection, 2000
		@queue            = new Queue()

	handleCollection: (groups) =>
		return log.error "No applications available (empty groups)" if isEmpty groups

		@groupManager.updateGroupConfigurations groups

		names  = @groupManager.getGroups()
		groups = pickBy @groupManager.getGroupConfigurations(), (_, name) -> name in names

		@queueUpdate groups, names

	queueUpdate: (globalGroups, groups) ->
		globalGroups or= @groupManager.getGroupConfigurations()
		groups       or= @groupManager.getGroups()

		try
			await @docker.createSharedVolume()
			await @queue.add partial @doUpdate, globalGroups, groups
		catch error
			log.error "Failed to update: #{error.message or error}"

	rearrange: (source) ->
		return source if firstKey(source) is "default"

		copy = omit source, "default"
		copy = Object.assign {}, default: source.default or {}, copy

		copy

	doUpdate: (globalGroups, groups) =>
		debug "Global groups are", globalGroups
		debug "Device groups are", groups

		throw new Error "No global groups"                if isEmpty globalGroups
		throw new Error "No default group"                unless globalGroups["default"]

		log.info "Calculating updates ..."

		groups         = @rearrange groups unless first(Object.keys globalGroups) is "default"
		currentApps    = await @docker.listContainers()
		currentApps    = {} unless config.docker.container.allowRemoval
		currentApps    = omit currentApps, config.docker.container.whitelist
		extendedGroups = createGroupsMixin globalGroups,   groups
		appsToChange   = getAppsToChange   extendedGroups, currentApps
		updatesCount   = appsToChange.install.length + appsToChange.remove.length

		@state.sendNsState
			updateState:
				short: "Idle"
				long:  "Idle"

		if updatesCount
			log.info kleur.cyan "#{updatesCount} application(s) to update/remove"
		else
			return log.info kleur.green "Applications are up to date."

		message = []
		install = map(appsToChange.install, "applicationName").join ", "
		remove  = appsToChange.remove.join ", "

		if appsToChange.install.length
			message.push "Installing: #{install}"
			log.info "Installing application(s): #{install}"
		else
			log.warn "No applications to install"

		if appsToChange.remove.length
			message.push "Removing: #{install}"
			log.info "Removing application(s): #{remove}"
		else
			log.warn "No applications to remove"

		@state.sendNsState
			updateState:
				short: "Updating applications ..."
				long:  message.join "\n"

		try
			# Verifying authentication does not work properly for GitLab registries
			# await @docker.verifyAuthentication() if @docker.isAuthenticationEnabled()
			await @docker.removeUntaggedImages()
			await @removeApps  appsToChange.remove
			await @installApps appsToChange.install
			await @docker.removeOldImages()

			@state.sendNsState
				updateState:
					short: "Idle"
					long:  "Idle"
		catch error
			log.error kleur.yellow "Failed to update: #{error.message}"

			if error.code is "ERR_CORRUPTED_LAYER"
				@state.sendNsState
					updateState:
						short: "ERROR: Layer corrupted"
						long:  error.message
			else
				@state.sendNsState
					updateState:
						short: "ERROR"
						long:  error.message
		finally
			@state.throttledSendState()

		appsToChange.install.length + appsToChange.remove.length

	removeApps: (apps) ->
		await Promise.all apps.map (app) =>
			@docker.removeContainer
				id:    app
				force: true

	installApps: (apps) ->
		await Promise.all apps.map (app) =>
			@installApp app

	installApp: (appConfig) ->
		normalized      = @normalizeAppConfiguration appConfig
		{ name, Image } = normalized

		return if @isPastLastInstallStep "Pull", appConfig.lastInstallStep

		try
			await @docker.pullImage name: Image
		catch error
			throw error unless error.code is "ERR_CORRUPTED_LAYER"

			if config.docker.retry.removeCorruptedLayer
				log.warn "Corrupted layer (#{Image}), removing and continuing ..."
				await removeRecursively error.target
				await @docker.pullImage name: Image

		return if @isPastLastInstallStep "Clean", appConfig.lastInstallStep
		await @docker.removeContainer id: name, force: true

		await @docker.createVolumeIfNotExists name

		return if @isPastLastInstallStep "Create", appConfig.lastInstallStep
		await @docker.createContainer normalized

		return if @isPastLastInstallStep "Start", appConfig.lastInstallStep
		await @docker.startContainer name

	isPastLastInstallStep: (currentStepName, endStepName) ->
		return false unless endStepName?

		steps = ["Pull", "Clean", "Create", "Start"]

		currentStep = steps.indexOf(currentStepName) + 1
		endStep     = steps.indexOf(endStepName)     + 1

		currentStep > endStep

	addVolumes: (name, mounts = []) ->
		mountsToAppend = [
			source:      @docker.getVolumeName name
			destination: "/data"
			flag:        "rw"
		,
			source:      @docker.getSharedVolumeName()
			destination: "/share"
			flag:        "rw"
		]

		mounts
			.filter (mount) ->
				[source, destination] = mount.split ":"
				return true unless destination in map mountsToAppend, "destination"

				log.error "Not mounting source #{source} to #{destination} for #{kleur.cyan name}: destination is reserved"
				false
			.concat mountsToAppend.map ({ source, destination, flag }) ->
				[source, destination, flag].join ":"

	normalizeAppConfiguration: (appConfiguration) ->
		{ containerName, mounts } = appConfiguration
		mounts                    = @addVolumes containerName, mounts if appConfiguration.createVolumes

		name:         containerName
		AttachStdin:  not appConfiguration.detached
		AttachStdout: not appConfiguration.detached
		AttachStderr: not appConfiguration.detached
		Image:        appConfiguration.fromImage
		Labels:       appConfiguration.labels #NOTE https://docs.docker.com/config/labels-custom-metadata/#value-guidelines
		Env:          appConfiguration.environment
		HostConfig:
			Binds:         mounts
			NetworkMode:   appConfiguration.networkMode
			Privileged:    not not appConfiguration.privileged
			RestartPolicy: Name: appConfiguration.restartPolicy
			PortBindings:  appConfiguration.ports or {}

	# unused for now
	bindsToMounts: (binds) ->
		binds.map (bind) ->
			[source, target, ro] = bind.split ":"

			ReadOnly: not not ro
			Source:   source
			Target:   target
			Type:     "bind"

module.exports = AppUpdater
