_                                      = require "underscore"
async                                  = require "async"
debug                                  = (require "debug") "app:app-updater"
{ createGroupsMixin, getAppsToChange } = require "@viriciti/app-layer-logic"

log                                    = (require "../lib/Logger") "App Updater"

module.exports = (docker, state) ->
	# We immediately set the update state to idle. At this point the socket is not connected and the publish will fail
	# This does not matter though. Because we also set the internal nsState and when the socket does connect we send the
	# nsState.
	state.publishNamespacedState updateState: { short: "Idle", long: "Idle" }

	queue = async.queue ({ func, meta }, cb) ->
		func cb

	_handleCollection = (label, collection) ->
		debug "Incoming collection", label

		# guard: only handle groups
		return debug "Imcoming collection is not groups" if label isnt "groups"

		# guard: collection may not be falsy
		return log.error "Incoming collection is", collection if _.isEmpty collection

		groups = collection
		state.setGlobalGroups groups

		deviceGroups = _(state.getGroups()).values()

		groups = _(groups).reduce (memo, apps, name) ->
			memo[name] = apps if _(deviceGroups).contains name
			memo
		, {}

		queueUpdate groups, state.getGroups(), (error, result) ->
			return log.error error.message if error
			log.info "Device updated correctly!"

	debouncedHandleCollection = _.debounce _handleCollection, 2000

	queueUpdate = (globalGroups, deviceGroups, cb) ->
		log.info "Pushing update task in queue"
		queue.push
			func: (cb) ->
				update globalGroups, deviceGroups, cb
			meta:
				timestamp: Date.now()
		, cb

	update = (globalGroups, deviceGroups, cb) ->
		debug "Updating..."
		debug "Global groups are", globalGroups
		debug "Device groups are", deviceGroups

		return cb new Error "Global groups is empty! Not proceeding." if _.isEmpty globalGroups

		if ((_(globalGroups).size() is 1) and not _(globalGroups).has "default")
			return cb new Error "Size of global groups is 1, but the group is not default.
				Global groups are misconfigured!"

		async.waterfall [
			(cb) ->
				docker.listContainers (error, containers) ->
					return cb error if error
					# Convert array into hashmap keyed on container name
					cb null, _.object _.pluck(containers, "name"), containers

			(currentApps, next) ->
				debug "Current applications are #{JSON.stringify _.keys currentApps}"

				extendedGroups = createGroupsMixin globalGroups,   deviceGroups
				debug "Mixin applications are   #{JSON.stringify _.keys extendedGroups}"
				appsToChange   = getAppsToChange   extendedGroups, currentApps

				next null, appsToChange

			(appsToChange, next) ->
				return setImmediate next unless appsToChange.install.length or appsToChange.remove.length

				state.publishNamespacedState
					updateState:
						short: "Updating applications..."
						long:  "Updating applications..."

				async.series [
					(cb) ->
						docker.removeOldImages cb

					(cb) ->
						docker.removeUntaggedImages cb

					(cb) ->
						log.info "No apps to be removed." if _(appsToChange.remove).isEmpty()
						_removeApps appsToChange.remove, cb

					(cb) ->
						log.info "No apps to be installed." if _(appsToChange.install).isEmpty()
						_installApps appsToChange.install, cb

					(cb) ->
						docker.removeOldImages cb

				], next

		], (error) ->
			state.throttledSendState()

			if error
				log.error "Error during update: #{error.message}"
				state.publishNamespacedState
					updateState:
						short: "ERROR!"
						long:  error.message

				return cb error

			log.info "Updating done."
			state.publishNamespacedState
				updateState:
					short: "Idle"
					long:  "Idle"
			cb()

	_removeApps = (apps, cb) ->
		async.eachSeries apps, (app, cb) ->
			docker.removeContainer id: app, force: true, cb
		, cb

	_installApps = (apps, cb) ->
		async.eachSeries apps, (appConfig, cb) ->
			log.info "Installing #{appConfig.containerName}..."
			_installApp appConfig, cb
		, cb

	_pastLastInstallStep = (currentStepName, endStepName) ->
		return false unless endStepName?

		steps = [ "Pull", "Clean", "Create", "Start" ]

		currentStep = steps.indexOf(currentStepName) + 1
		endStep     = steps.indexOf(endStepName)     + 1
		currentStep > endStep

	_installApp = (appConfig, cb) ->
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
			(next) ->
				return next() if _pastLastInstallStep("Pull", appConfig.lastInstallStep)

				docker.pullImage name: containerInfo.Image, (error) ->
					return next error if error
					log.info "Image #{containerInfo.Image} pulled correctly."
					next()
			(next) ->
				return next() if _pastLastInstallStep("Clean", appConfig.lastInstallStep)

				docker.getContainerByName containerInfo.name, (error, c) ->
					return next() if not c
					docker.removeContainer id: containerInfo.name, force: true, next
			(next) ->
				return next() if _pastLastInstallStep("Create", appConfig.lastInstallStep)

				docker.createContainer containerProps: containerInfo, next
			(next) ->
				return next() if _pastLastInstallStep("Start", appConfig.lastInstallStep)

				docker.startContainer id: containerInfo.name, next
		], (error, result) ->
			return cb error if error

			log.info "Application #{containerInfo.name} installed correctly!"
			cb()


	return {
		update
		queueUpdate
		debouncedHandleCollection
	}
