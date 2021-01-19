config = require "config"
debug  = (require "debug") "app:AppUpdater"
kleur  = require "kleur"
rmrf   = require "rmfr"
Queue  = require "p-queue"
{
	createGroupsMixin,
	getAppsToChange
}  = require "@viriciti/app-layer-logic"
{
	isEmpty,
	isPlainObject,
	pickBy,
	first,
	compact,
	find,
	flatten,
	filter,
	sortBy,
	debounce,
	each,
	map,
	omit,
	partial,
	reduce,
	keys,
	without
} = require "lodash"

log               = (require "../lib/Logger") "AppUpdater"
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
		debug "queueUpdate called"

		globalGroups or= @groupManager.getGroupConfigurations()
		groups       or= @groupManager.getGroups()

		try
			await @docker.createSharedVolume()
			await @queue.add partial @doUpdate, globalGroups, groups
			await @recreateUnhealthyContainers()
		catch error
			log.error "Failed to update: #{error.message or error}"

	rearrange: (source) ->
		if isPlainObject source
			return source if firstKey(source) is "default"

			copy = omit source, "default"
			copy = Object.assign {}, default: source.default or {}, copy

			copy
		else
			return source if first(source) is "default"

			copy = without source, "default"
			copy = ["default", ...copy]

			copy

	accountForNotRunning: (currentApps) ->
		appsToDelete = reduce currentApps, (m, container, name) ->
			id              = container.Id
			isRunning       = container.state?.running
			isAlwaysRestart = container.restartPolicy?.type is "always"
			if not isRunning and isAlwaysRestart
				log.warn "App `#{name}` with restart policy `always` is not running. Scheduled for removal and recreation.."
				m.push { name, id }
			m
		, []

		if appsToDelete.length
			log.warn "Apps not running: #{(map appsToDelete, "name").join ", "}"
		else
			log.info "No apps found in wrong state"

		await @removeApps map appsToDelete, "id"
		omit currentApps, map appsToDelete, "name"

	doUpdate: (globalGroups, groups) =>
		debug "doUpdate: Global groups are", globalGroups
		debug "doUpdate: Device groups are", groups

		throw new Error "No global groups" if isEmpty globalGroups
		throw new Error "No default group" unless globalGroups["default"]

		@globalGroups = globalGroups
		@groups       = groups

		log.info "Calculating updates ..."

		groups         = @rearrange @groups unless first(Object.keys @globalGroups) is "default"
		currentApps    = await @docker.listContainers()
		currentApps    = {} unless config.docker.container.allowRemoval
		currentApps    = omit currentApps, config.docker.container.whitelist
		currentApps    = await @accountForNotRunning currentApps

		extendedGroups = createGroupsMixin @globalGroups,   groups
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
			message.push "Removing: #{remove}"
			log.warn "Removing application(s): #{remove}"
		else
			log.info "No applications to remove"

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

	handleLog: (data) ->
		return unless data.health
		return if data.health isnt "unhealthy"

		log.warn "Identified unhealthy app from log events: #{data.action.name}"
		@recreateUnhealthyContainers()

	recreateUnhealthyContainers: ->
		log.info "Checking for unhealthy apps..."
		apps = await @docker.listContainers JSON.stringify health: ["unhealthy"]
		apps = reduce apps, (arr, app, name) ->
			if app.labels?.group and app.labels?.manual is "false"
				arr.push { id: app.Id, name, group: app.labels?.group }
			arr
		, []

		return log.info "Found no unhealthy apps :)" unless apps.length

		log.warn "Detected #{apps.length} apps in unhealthy state: #{(map apps, "name").join ", "}"

		await Promise.all apps.map (app) =>
			log.warn "Removing container #{app.name} (group #{app.group}) due to unhealthy state"
			@docker.removeContainer id: app.id, force: true

		return if not @globalGroups["default"]
		return if isEmpty @globalGroups

		await @queue.add partial @doUpdate, @globalGroups, @groups

	removeApps: (apps) ->
		await Promise.all apps.map (app) =>
			@docker.removeContainer
				id:    app
				force: true

	installApps: (apps) ->
		# deep clone ;)
		apps = JSON.parse JSON.stringify apps

		# add a dependency count
		each apps, (app) ->
			each (app.dependencies or []), (dependency) ->
				dep = find apps, applicationName: dependency
				if dep
					dep.dependencyCount ?= 0
					dep.dependencyCount++

		# recusrive sorting based on dependeny
		sortFn = (app) ->
			app.visited = true
			app.dependencies or= []
			(flatten map app.dependencies, (dependency) ->
				dep = find apps, applicationName: dependency
				return unless dep
				sortFn dep unless dep.visited
			).concat app

		order  = compact flatten map apps, (app) -> sortFn app unless app.visited
		head   = filter order, (app) -> app.dependencyCount
		head   = sortBy head, (app) -> -1 * app.dependencyCount or 0
		tail   = filter order, (app) -> not app.dependencyCount
		tail   = sortBy tail, (app) -> -1 * (app.dependencies?.length or 0)
		result = head.concat tail

		log.info "Installing apps: #{(map result, "applicationName").join " → "}"

		await @installApp app for app in result

	installApp: (appConfig) ->
		normalized      = @normalizeAppConfiguration appConfig
		{ name, Image } = normalized

		return if @isPastLastInstallStep "Pull", appConfig.lastInstallStep

		debug "Starting while loop on image pull"
		whileLoopCount = 0
		while true
			++whileLoopCount
			try
				debug "While loop count #{whileLoopCount}: calling docker pull image"
				await @docker.pullImage name: Image

				debug "While loop count #{whileLoopCount}: breaking the loop"
				# When we reach this point, the image has been pulled succesfully
				break
			catch error
				debug "While loop count #{whileLoopCount}: caught an error: #{error.message}", error
				log.error "Got an error pulling image `#{Image}`: #{error.message}"

				throw error unless (
					error.code is "ERR_CORRUPTED_LAYER" and
					config.docker.retry.removeCorruptedLayer
				)

				debug "While loop count #{whileLoopCount}: removing target from error message: #{error.target}"
				log.warn "Corrupted layer (#{Image}, directory: #{error.target}), removing and continuing ..."
				await rmrf error.target
				debug "While loop count #{whileLoopCount}: Removing done"

				if whileLoopCount is config.docker.retry.maxAttempts
					log.warn "Tried to pull image #{Image} #{config.docker.retry.maxAttempts} times. Really stopping this now."
					throw new Error "Max retry for Docker pull reached."

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
