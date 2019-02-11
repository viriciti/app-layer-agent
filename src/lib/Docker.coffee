Dockerode                                    = require "dockerode"
async                                        = require "async"
config                                       = require "config"
{ EventEmitter }                             = require "events"
{ every, isEmpty, compact, random }          = require "lodash"
{ filterUntaggedImages, getRemovableImages } = require "@viriciti/app-layer-logic"
debug                                        = (require "debug") "app:Docker"

log              = (require "./Logger") "Docker"
DockerLogsParser = require "./DockerLogsParser"

class Docker extends EventEmitter
	constructor: ->
		super()

		log.warn "Container removal is disabled" unless config.docker.container.allowRemoval

		@dockerClient = new Dockerode socketPath: config.docker.socketPath

		@listenForEvents()

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
		stream = await @dockerClient.getEvents()
		stream
			.on "data",  onData
			.on "error", onError
			.once "end", ->
				stream.removeListener "data",  onData
				stream.removeListener "error", onError
				stream.push null

	getDockerInfo: =>
		info = await @dockerClient.version()

		apiVersion: info.ApiVersion
		version:    info.Version
		kernel:     info.KernelVersion

	pullImage: ({ name }) =>
		log.info "Pulling image '#{name}'..."

		new Promise (resolve, reject) =>
			credentials  = null
			credentials  = config.docker.registryAuth.credentials if every config.docker.registryAuth.credentials
			retryIn      = 1000 * 60
			pullInterval = setInterval =>
				@emit "logs",
					message: "Pulling #{name}"
					image: name
					type:  "action"
					time:  Date.now()
			, 3000

			async.retry
				times: config.docker.retry.maxAttempts
				interval: ->
					retryIn
				errorFilter: (error) ->
					debug "Pulling #{name} failed, error code: #{error.statusCode}"
					return false unless error.statusCode in config.docker.retry.errorCodes

					retryIn = random config.docker.retry.minWaitingTime, config.docker.retry.maxWaitingTime
					log.warn "Pulling #{name} failed, retrying after #{retryIn}ms"

					true
			, (next) =>
				options            = {}
				options.authconfig = credentials if credentials

				@dockerClient.pull name, options, (error, stream) =>
					if error
						if error.message.match /unauthorized/
							log.error "No permission to pull #{name}"
						else unless error.statusCode in config.docker.retry.errorCodes
							log.error error.message

						return next error

					@dockerClient.modem.followProgress stream, next
			, (error) ->
				clearInterval pullInterval

				return reject error if error
				resolve()

	listImages: =>
		images = await @dockerClient.listImages()
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
		images         = await @dockerClient.listImages()
		untaggedImages = filterUntaggedImages images

		log.info "Found #{untaggedImages.length} untagged images"

		Promise.all untaggedImages.map (image) =>
			@removeImage
				id:     image.Id
				gentle: true

	getImageByName: (name) ->
		info = await @dockerClient.getImage(name).inspect()

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
			await @dockerClient.getImage(entity).remove()
			log.info "Removed image #{entity} successfully"
		catch error
			if error.statusCode is 409
				log.warn "Conflict: image #{@getShortenedImageId entity} is used by a container"
			else
				log.error error.message
				throw error

	listContainers: =>
		containers         = await @dockerClient.listContainers all: true
		containersDetailed = await Promise.all containers.map (container) =>
			# container.Names is an array of names in the format "/name"
			# only the first name after the slash is needed
			@getContainerByName container.Names[0].replace "/", ""

		compact containersDetailed

	getContainerByName: (name) =>
		try
			container = await @dockerClient
				.getContainer name
				.inspect size: 1

			return unless container

			@serializeContainer container
		catch error
			return undefined if error.statusCode is 404
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
		log.info "Creating container #{containerProps.name} ..."

		try
			await @dockerClient.createContainer containerProps

			log.info "Created container #{containerProps.name}"
		catch error
			if error.statusCode is 409
				log.error "A container with the name #{containerProps.name} already exists"
			else unless error.statusCode in config.docker.retry.errorCodes
				log.error error.message

			throw error

	startContainer: (id) ->
		log.info "Starting container #{id} ..."

		@dockerClient
			.getContainer id
			.start()

	restartContainer: (id) ->
		log.info "Restarting container #{id} ..."

		@dockerClient
			.getContainer id
			.restart()

	removeContainer: ({ id, force = false }) ->
		log.info "Removing container '#{id}'"

		containers = await @listContainers()
		toRemove   = containers.filter (c) -> c.name.includes id

		await Promise.all toRemove.map (container) =>
			@dockerClient
				.getContainer container.Id
				.remove force: force

		log.info "Removed #{toRemove.length} containers"

	getContainerLogs: (id) ->
		container = @dockerClient.getContainer id
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

module.exports = Docker
