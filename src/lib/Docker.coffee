Dockerode                                    = require "dockerode"
async                                        = require "async"
config                                       = require "config"
{ EventEmitter }                             = require "events"
{ every, isEmpty, random, find }             = require "lodash"
{ filterUntaggedImages, getRemovableImages } = require "@viriciti/app-layer-logic"
debug                                        = (require "debug") "app:Docker"

log              = (require "./Logger") "Docker"
DockerLogsParser = require "./DockerLogsParser"

class Docker extends EventEmitter
	constructor: ->
		super()

		log.warn "Container removal is disabled" unless config.docker.container.allowRemoval
		log.warn "Authentication is disabled"    unless @isAuthenticationEnabled()

		@dockerode = new Dockerode socketPath: config.docker.socketPath
		@listenForEvents()

	isAuthenticationEnabled: ->
		config.docker.registryAuth.credentials and every config.docker.registryAuth.credentials

	listenForEvents: ->
		onData = (event) =>
			try
				@emit "logs", parser.parseLogs JSON.parse event
			catch error
				log.error "Error parsing event: #{error.message}"
				@emit "error", error

		onError = (error) =>
			@emit "error", error

		parser = new DockerLogsParser @
		stream = await @dockerode.getEvents()
		stream
			.on "data",  onData
			.on "error", onError
			.once "end", ->
				stream.removeListener "data",  onData
				stream.removeListener "error", onError
				stream.push null

	getDockerInfo: =>
		info = await @dockerode.version()

		apiVersion: info.ApiVersion
		version:    info.Version
		kernel:     info.KernelVersion

	pullImage: ({ name }, force = false) =>
		return log.warn "Skipping #{name}, image is already downloaded" if find await @listImages(), name: name

		log.info "Downloading #{name} (retrying on status codes #{config.docker.retry.errorCodes.join ', '})..."
		new Promise (resolve, reject) =>
			retryIn       = 1000 * 60
			pullInterval  = setInterval =>
				@emit "logs",
					message: "Downloading #{name} ..."
					image: name
					type:  "action"
					time:  Date.now()
			, 3000

			# Unauthorized errors are rejected
			# due to the lack of recovery
			handleUnauthorized = (error) ->
				error      = new Error "No permission to download #{name}"
				error.code = "ERR_DOCKER_UNAUTHORIZED"
				clearInterval pullInterval
				reject error

			handleCorruptedLayer = (message) ->
				matches = /(\/.+) (\/.+):/g.exec message
				error   = new Error message
				unless matches?
					clearInterval pullInterval
					return reject error

				[, source, target] = matches
				error              = new Error "Corrupted layer: #{source} → #{target}"
				error.code         = "ERR_CORRUPTED_LAYER"
				error.source       = source
				error.target       = target

				clearInterval pullInterval
				reject error

			handleGenericError = (error) ->
				log.error "Error while downloading #{name}: #{error.message}"

			async.retry
				times: config.docker.retry.maxAttempts
				interval: ->
					retryIn
				errorFilter: (error) ->
					return handleCorruptedLayer error if (
						error.message?.match(/failed to register layer/i) or
						error.match? /failed to register layer/i
					)

					debug "Downloading #{name} failed, error code: #{error.statusCode}"
					return false unless error.statusCode in config.docker.retry.errorCodes

					retryIn = random config.docker.retry.minWaitingTime, config.docker.retry.maxWaitingTime
					log.warn "Downloading #{name} failed, retrying after #{retryIn}ms"

					true
			, (next) =>
				options            = {}
				options.authconfig = config.docker.registryAuth.credentials if @isAuthenticationEnabled()

				@dockerode.pull name, options, (error, stream) =>
					if error
						handleUnauthorized error if error.message?.match /unauthorized/i
						handleGenericError error unless error.statusCode in config.docker.retry.errorCodes
						return next error

					@dockerode.modem.followProgress stream, next
			, (error) ->
				clearInterval pullInterval

				return reject error if error
				resolve()

	listImages: =>
		images = await @dockerode.listImages()
		images = images.filter (image) ->
			(image.RepoTags isnt null) and (image.RepoTags[0] isnt "<none>:<none>")

		Promise.all images.map (image) =>
			@getImageByName image.RepoTags[0]

	removableImages: =>
		[containers, images] = await Promise.all [@listContainers(), @listImages()]

		getRemovableImages containers, images

	removeOldImages: =>
		toRemove = await @removableImages()

		Promise.all toRemove.map (name) =>
			@removeImage name: name

	removeUntaggedImages: ->
		images         = await @dockerode.listImages()
		untaggedImages = filterUntaggedImages images

		log.info "Found #{untaggedImages.length} untagged images"

		Promise.all untaggedImages.map (image) =>
			@removeImage
				id:     image.Id
				gentle: true

	getImageByName: (name) ->
		info = await @dockerode.getImage(name).inspect()

		id:          info.Id
		name:        name
		size:        info.Size
		tags:        info.RepoTags
		virtualSize: info.VirtualSize

	removeImage: ({ name, id }) ->
		entity   = id
		entity or= name

		log.info "Removing image #{@getShortenedImageId entity}"

		try
			await @dockerode.getImage(entity).remove()
			log.info "Removed image #{entity} successfully"
		catch error
			if error.statusCode is 409
				log.warn "Conflict: image #{@getShortenedImageId entity} is used by a container"
			else
				log.error error.message
				throw error

	listContainers: (filters) =>
		params = { all: true, filters }

		debug "listContainers, with params", params

		containers         = await @dockerode.listContainers params
		containersDetailed = await Promise.all containers.map (container) =>
			name = container.Names[0].replace "/", ""
			[name, await @getContainerByName name]

		containersDetailed.reduce (grouped, [name, container]) ->
			return grouped unless container

			grouped[name] = container
			grouped
		, {}

	getContainerByName: (name) =>
		try
			container = await @dockerode
				.getContainer name
				.inspect size: 1

			return unless container

			@serializeContainer container
		catch error
			return log.warn "Container #{name} not found" if error.statusCode is 404
			throw error

	serializeContainer: (containerInfo) ->
		Id:       containerInfo.Id
		name:     containerInfo.Name.replace "/", ""
		commands: containerInfo.Config.Cmd
		restartPolicy:
			type:            containerInfo.HostConfig.RestartPolicy.Name
			maxRetriesCount: containerInfo.HostConfig.RestartPolicy.MaximumRetryCount
		privileged:  containerInfo.HostConfig.Privileged
		readOnly:    containerInfo.HostConfig.ReadonlyRootfs
		image:       containerInfo.Config.Image
		networkMode: containerInfo.HostConfig.NetworkMode
		state:
			status:   containerInfo.State.Status
			exitCode: containerInfo.State.ExitCode
			running:  containerInfo.State.Running
			health:   containerInfo.State.Health?.Status
		ports:          containerInfo.HostConfig.PortBindings
		environment:    containerInfo.Config.Env
		sizeFilesystem: containerInfo.SizeRw          # in bytes
		sizeRootFilesystem: containerInfo.SizeRootFs # in bytes
		mounts: containerInfo.Mounts.filter (mount) ->
			hostPath:      mount.Source
			containerPath: mount.Destination
			mode:          mount.Mode
		labels: containerInfo.Config.Labels

	createContainer: (containerProps) ->
		debug "Creating container #{containerProps.name} ..."

		try
			await @dockerode.createContainer containerProps

			debug "Created container #{containerProps.name}"
		catch error
			if error.statusCode is 409
				log.error "A container with the name #{containerProps.name} already exists"
			else unless error.statusCode in config.docker.retry.errorCodes
				log.error error.message

			throw error

	startContainer: (id) ->
		debug "Starting container #{id} ..."

		@dockerode
			.getContainer id
			.start()

	restartContainer: (id) ->
		debug "Restarting container #{id} ..."

		@dockerode
			.getContainer id
			.restart()

	stopContainer: (id) ->
		debug "Stopping container #{id} ..."

		@dockerode
			.getContainer id
			.stop()

	removeContainer: ({ id, force = false }) ->
		debug "Removing container #{id} ..."

		try
			await @dockerode
				.getContainer id
				.remove force: force
		catch error
			return Promise.resolve() if error.statusCode is 404
			throw error

	getContainerLogs: (id) ->
		container = @dockerode.getContainer id
		options   =
			stdout: true
			stderr: true
			tail:   100
			follow: false

		logs   = await container.logs options
		logs or= ""

		logs
			.split  "\n"
			.filter (line) -> not isEmpty line
			.map    (line) -> line.substr 8, line.length - 1

	getShortenedImageId: (id) ->
		return id unless id.startsWith "sha256:"

		id.substring 7, 7 + 12

	getVolumeName: (name) ->
		"app-layer-agent-#{name}"

	getSharedVolumeName: ->
		"shared-app-layer-agent"

	pruneImages: ->
		await @dockerode.pruneImages filters: dangling: 'false' : true

	createSharedVolume: (name) ->
		try
			volume = await @dockerode.getVolume @getSharedVolumeName()
			data   = await volume.inspect()

			debug "Shared volume exists (internal: #{data.Name})"
		catch error
			throw error unless error.statusCode is 404

			debug "Creating shared volume ..."
			await @dockerode.createVolume Name: @getSharedVolumeName()

	createVolumeIfNotExists: (name) ->
		try
			volume = await @dockerode.getVolume @getVolumeName name
			data   = await volume.inspect()

			debug "Volume exists for #{name} (internal: #{data.Name})"
		catch error
			throw error unless error.statusCode is 404

			debug "Creating volume for #{name} ..."
			await @dockerode.createVolume Name: @getVolumeName name

	verifyAuthentication: ->
		try
			await @dockerode.checkAuth config.docker.registryAuth.credentials
			true
		catch original
			error          = new Error "Incorrect username or password"
			error.code     = "ERR_AUTH_INCORRECT"
			error.original = original

			throw error

module.exports = Docker
