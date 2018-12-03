{ isEmpty, pickBy, size, debounce, map } = require "lodash"
async                                    = require "async"
debug                                    = (require "debug") "app:AppUpdater"
{ createGroupsMixin, getAppsToChange }   = require "@viriciti/app-layer-logic"
log                                      = (require "../lib/Logger") "AppUpdater"

class AppUpdater
	constructor: (@docker, @state) ->
		@handleCollection = debounce @handleCollection, 2000
		@queue            = async.queue ({ func, meta }, cb) -> func cb

	handleCollection: (groups) =>
		return log.error "No global groups are configured" if isEmpty groups

		@state.setGlobalGroups groups

		groupNames = Object.values @state.getGroups()
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

		return cb new Error "No groups" if isEmpty globalGroups

		if size(globalGroups) is 1 and not globalGroups["default"]
			return cb new Error "Size of global groups is 1, but the group is not default.
				Global groups are misconfigured!"

		async.waterfall [
			(next) =>
				@docker.listContainers (error, containers) ->
					return next error if error

					next null, containers.reduce (keyedContainers, container) ->
						{ keyedContainers..., [container.name]: container }
					, {}
			(currentApps, next) ->
				extendedGroups = createGroupsMixin globalGroups,   groups
				appsToChange   = getAppsToChange   extendedGroups, currentApps

				debug "Current applications are    #{JSON.stringify Object.keys currentApps}"
				debug "Calculated applications are #{JSON.stringify Object.keys extendedGroups}"

				next null, appsToChange
			(appsToChange, next) =>
				return setImmediate next unless (
					appsToChange.install.length or
					appsToChange.remove.length
				)

				message = []
				message.push "Installing: #{map(appsToChange.install, "applicationName").join ", "}" if appsToChange.install.length
				message.push "Removing: #{appsToChange.remove.join ", "}"                       if appsToChange.remove.length

				@state.publishNamespacedState
					updateState:
						short: "Updating applications..."
						long:  message.join "\n"

				async.series [
					(cb) =>
						@docker.removeOldImages cb
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
		containerInfo =
			name:         appConfig.containerName
			AttachStdin:  not appConfig.detached
			AttachStdout: not appConfig.detached
			AttachStderr: not appConfig.detached
			Env:          appConfig.environment
			Cmd:          appConfig.entryCommand
			Image:        appConfig.fromImage
			Labels:       appConfig.labels #NOTE https://docs.docker.com/config/labels-custom-metadata/#value-guidelines
			HostConfig:
				Binds:         appConfig.mounts
				NetworkMode:   appConfig.networkMode
				Privileged:    not not appConfig.privileged
				RestartPolicy: Name: appConfig.restartPolicy # why 0?
				PortBindings:  appConfig.ports

		async.series [
			(next) =>
				return next() if @isPastLastInstallStep "Pull", appConfig.lastInstallStep

				@docker.pullImage name: containerInfo.Image, (error) ->
					return next error if error
					log.info "Image #{containerInfo.Image} pulled correctly."
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

module.exports = AppUpdater
