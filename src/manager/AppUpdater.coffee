{ isEmpty, pickBy, first, debounce, map } = require "lodash"
async                                     = require "async"
debug                                     = (require "debug") "app:AppUpdater"
{ createGroupsMixin, getAppsToChange }    = require "@viriciti/app-layer-logic"
log                                       = (require "../lib/Logger") "AppUpdater"

class AppUpdater
	constructor: (@docker, @state) ->
		@handleCollection = debounce @handleCollection, 2000
		@queue            = async.queue ({ func, meta }, cb) -> func cb

	handleCollection: (groups) =>
		return log.error "No global groups are configured" if isEmpty groups

		@state.setGlobalGroups groups

		groupNames = @state.getGroups()
		groups     = pickBy groups, (_, name) -> name in groupNames

		@queueUpdate groups, @state.getGroups(), (error, result) ->
			return log.error error.message if error
			log.info "Device updated correctly!"

	queueUpdate: (globalGroups, groups, cb) ->
		log.info "Pushing update task in queue"

		@queue.push
			func: (cb) =>
				@update globalGroups, groups, cb
			meta:
				timestamp: Date.now()
		, cb

	update: (globalGroups, groups, cb) ->
		debug "Updating..."
		debug "Global groups are", globalGroups
		debug "Device groups are", groups

		return cb new Error "No groups"                       if isEmpty globalGroups
		return cb new Error "No default group"                unless globalGroups["default"]
		return cb new Error "Default group must appear first" unless first(Object.keys globalGroups) is "default"

		async.waterfall [
			(next) =>
				@docker.listContainers (error, containers) ->
					return next error if error

					currentApps = containers.reduce (keyedContainers, container) ->
						{ keyedContainers..., [container.name]: container }
					, {}
					extendedGroups = createGroupsMixin globalGroups,   groups
					appsToChange   = getAppsToChange   extendedGroups, currentApps

					next null, appsToChange
			(appsToChange, next) =>
				return setImmediate next unless (
					appsToChange.install.length or
					appsToChange.remove.length
				)

				message = []
				message.push "Installing: #{map(appsToChange.install, "applicationName").join ", "}" if appsToChange.install.length
				message.push "Removing: #{appsToChange.remove.join ", "}"                            if appsToChange.remove.length

				@state.publishNamespacedState
					updateState:
						short: "Updating applications..."
						long:  message.join "\n"

				async.series [
					(cb) =>
						@docker.removeUntaggedImages cb
					(cb) =>
						log.info "No apps to be removed" if isEmpty appsToChange.remove
						@removeApps appsToChange.remove, cb
					(cb) =>
						log.info "No apps to be installed" if isEmpty appsToChange.install
						@installApps appsToChange.install, cb
					(cb) =>
						@docker.removeOldImages cb
				], next

		], (error) =>
			@state.throttledSendState()

			if error
				log.error "Error during update: #{error.message}"
				@state.publishNamespacedState
					updateState:
						short: "ERROR!"
						long:  error.message

				return cb error

			log.info "Updating done"
			@state.publishNamespacedState
				updateState:
					short: "Idle"
					long:  "Idle"
			cb()

	removeApps: (apps, cb) ->
		async.eachSeries apps, (app, cb) =>
			@docker.removeContainer id: app, force: true, cb
		, cb

	installApps: (apps, cb) ->
		async.eachSeries apps, (appConfig, cb) =>
			log.info "Installing #{appConfig.containerName} ..."
			@installApp appConfig, cb
		, cb

	isPastLastInstallStep: (currentStepName, endStepName) ->
		return false unless endStepName?

		steps = [ "Pull", "Clean", "Create", "Start" ]

		currentStep = steps.indexOf(currentStepName) + 1
		endStep     = steps.indexOf(endStepName)     + 1
		currentStep > endStep

	installApp: (appConfig, cb) ->
		containerInfo = @normalizeAppConfiguration appConfig

		async.series [
			(next) =>
				return next() if @isPastLastInstallStep "Pull", appConfig.lastInstallStep

				@docker.pullImage name: containerInfo.Image, (error) ->
					return next error if error

					log.info "Image #{containerInfo.Image} pulled correctly"
					next()
			(next) =>
				return next() if @isPastLastInstallStep "Clean", appConfig.lastInstallStep

				@docker.getContainerByName containerInfo.name, (error, container) =>
					return next() unless container
					@docker.removeContainer id: containerInfo.name, force: true, next
			(next) =>
				return next() if @isPastLastInstallStep "Create", appConfig.lastInstallStep

				@docker.createContainer containerProps: containerInfo, next
			(next) =>
				return next() if @isPastLastInstallStep "Start", appConfig.lastInstallStep

				@docker.startContainer id: containerInfo.name, next
		], (error, result) ->
			return cb error if error

			log.info "Application #{containerInfo.name} installed correctly"
			cb()

	normalizeAppConfiguration: (appConfiguration) ->
		name:         appConfiguration.containerName
		AttachStdin:  not appConfiguration.detached
		AttachStdout: not appConfiguration.detached
		AttachStderr: not appConfiguration.detached
		Env:          appConfiguration.environment
		Cmd:          appConfiguration.entryCommand
		Image:        appConfiguration.fromImage
		Labels:       appConfiguration.labels #NOTE https://docs.docker.com/config/labels-custom-metadata/#value-guidelines
		HostConfig:
			Mounts:        @bindsToMounts appConfiguration.mounts
			NetworkMode:   appConfiguration.networkMode
			Privileged:    not not appConfiguration.privileged
			RestartPolicy: Name: appConfiguration.restartPolicy
			PortBindings:  appConfiguration.ports

	bindsToMounts: (binds) ->
		binds.map (bind) ->
			[source, target, ro] = bind.split ":"

			ReadOnly: not not ro
			Source:   source
			Target:   target
			Type:     "bind"

module.exports = AppUpdater
