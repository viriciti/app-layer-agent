{ EventEmitter }                             = require "events"
async                                        = require "async"
debug                                        = (require "debug") "app:Docker"
Dockerode                                    = require "dockerode"
jsonstream2                                  = require "jsonstream2"
moment                                       = require "moment"
pump                                         = require "pump"
S                                            = require "string"
{ every, isEmpty, compact, random }          = require "lodash"
{ filterUntaggedImages, getRemovableImages } = require "@viriciti/app-layer-logic"
config                                       = require "config"

log              = (require "./Logger") "Docker"
DockerLogsParser = require "./DockerLogsParser"

class Docker extends EventEmitter
	constructor: ->
		super()

		@dockerClient = new Dockerode socketPath: config.docker.socketPath
		@logsParser   = new DockerLogsParser @

		@dockerClient.getEvents (error, stream) =>
			@dockerEventStream = stream
			@emit "error", error if error

			@dockerEventStream
				.on "error", @handleStreamError
				.on "data",  @handleStreamData
				.once "end", ->
					log.warn "Closed connection to Docker daemon."

			@emit "status", "initiated"

	handleStreamError: (error) =>
		@emit "error", error

	handleStreamData: (event) =>
		try
			event = JSON.parse event
		catch error
			log.error "Error parsing event data:\n#{event.toString()}"
			return @emit "error", error

		@emit "logs", @logsParser.parseLogs event

	stop: ->
		@dockerEventStream.removeListener "error", @handleStreamError
		@dockerEventStream.removeListener "data",  @handleStreamData
		@dockerEventStream.push null

	getDockerInfo: (cb) =>
		@dockerClient.version (error, info) ->
			return cb error if error

			cb null,
				apiVerion: info.ApiVersion
				version:   info.Version
				kernel:    info.KernelVersion

	pullImage: ({ name }, cb) =>
		log.info "Pulling image '#{name}'..."

		credentials = null
		credentials = config.docker.registryAuth.credentials if every config.docker.registryAuth.credentials
		retryIn     = 1000 * 60

		async.retry
			times: config.docker.retry.maxAttempts
			interval: ->
				retryIn
			errorFilter: (error) ->
				return false unless error.statusCode in config.docker.retry.errorCodes

				retryIn = random config.docker.retry.minWaitingTime, config.docker.retry.maxWaitingTime
				log.warn "Pulling #{name} failed, retrying after #{retryIn}ms"

				true
		, (next) =>
			@dockerClient.pull name, { authconfig: credentials }, (error, stream) =>
				if error
					if error.message.match /unauthorized/
						log.error "No permission to pull #{name}"
					else unless error.statusCode in config.docker.retry.errorCodes
						log.error error.message

					return next error

				_pullingPingTimeout = setInterval =>
					debug "Emitting pull logs"
					@emit "logs",
						message: "Pulling #{name}"
						image: name
						type: "action"
						time: Date.now()
				, 3000

				pump [
					stream
					jsonstream2.parse()
				], (error) ->
					clearInterval _pullingPingTimeout

					next error
		, cb

	listImages: (cb) =>
		debug "Listing images ..."
		@dockerClient.listImages (error, images) =>
			return cb error if error

			images = images.filter (image) ->
				(image.RepoTags isnt null) and (image.RepoTags[0] isnt "<none>:<none>")

			debug "Found #{images.length} images"

			async.map images, (image, next) =>
				@getImageByName image.RepoTags[0], next
			, cb

	removableImages: (cb) =>
		async.parallel {
			runningContainers: @listContainers
			allImages:         @listImages
		}, (error, { runningContainers, allImages } = {}) ->
			return cb error if error

			cb null, getRemovableImages runningContainers, allImages

	removeOldImages: (cb) =>
		async.waterfall [
			@removableImages
			(toRemove, cb) =>
				async.eachSeries toRemove, (image, cb) =>
					@removeImage
						name: image
					, cb
				, cb
		], cb

	removeUntaggedImages: (cb) ->
		log.info "Removing untagged images ..."

		async.waterfall [
			(cb) =>
				@dockerClient.listImages cb
			(allImages, cb) =>
				untaggedImages = filterUntaggedImages allImages

				log.info "Found #{untaggedImages.length} untagged images"

				async.eachSeries untaggedImages, (image, cb) =>
					@removeImage { id: image.Id, gentle: true }, cb
				, cb
		], cb

	getImageByName: (name, cb) ->
		@dockerClient
			.getImage name
			.inspect (error, info) ->
				return cb error if error

				cb null, {
					id:          info.Id,
					name:        name,
					tags:        info.RepoTags,
					size:        info.Size,
					virtualSize: info.VirtualSize
				}

	removeImage: ({ name, id }, cb) ->
		entity   = id
		entity or= name

		log.info "Removing image #{@getShortenedImageId entity}"

		@dockerClient
			.getImage entity
			.remove (error) =>
				if error
					if error.statusCode is 409
						message = "Conflict: image #{@getShortenedImageId entity} is used by a container"
						log.warn message
						return cb null, message
					else
						log.error error.message
						return cb error

				log.info "Removed image #{entity} successfully"
				cb()

	listContainers: (cb) =>
		@dockerClient.listContainers all: true, (error, containers) =>
			return cb error if error

			async.map containers, (container, next) =>
				# container.Names is an array of names in the format "/name".
				# Only the first name after the slash is needed.
				@getContainerByName container.Names[0].replace("/", ""), (err, containerByName) ->
					return next()     unless containerByName
					return next error if error

					next null, containerByName
			, (error, formattedContainers) ->
				return cb error if error
				cb null, compact formattedContainers

	getContainerByName: (name, cb) =>
		@dockerClient
			.getContainer name
			.inspect size: 1, (error, info) =>
				return cb error if error
				cb null, @serializeContainer info

	serializeContainer: (containerInfo) ->
		started = moment(new Date(containerInfo.State.StartedAt)).fromNow()

		# TODO Do we want this?
		if not containerInfo.State.Running
			stopped = moment(new Date(containerInfo.State.FinishedAt)).fromNow()
		else
			stopped = ""

		Id            : containerInfo.Id
		name          : containerInfo.Name.replace "/", ""
		commands      : containerInfo.Config.Cmd
		restartPolicy :
			type: containerInfo.HostConfig.RestartPolicy.Name
			maxRetriesCount: containerInfo.HostConfig.RestartPolicy.MaximumRetryCount
		privileged    : containerInfo.HostConfig.Privileged
		readOnly      : containerInfo.HostConfig.ReadonlyRootfs
		image         : containerInfo.Config.Image
		networkMode   : containerInfo.HostConfig.NetworkMode
		state         :
			status:   containerInfo.State.Status
			exitCode: containerInfo.State.ExitCode
			running:  containerInfo.State.Running
			started:  started
			stopped:  stopped
		ports         : containerInfo.HostConfig.PortBindings
		environment   : containerInfo.Config.Env
		sizeFilesystem: containerInfo.SizeRw          # in bytes
		sizeRootFilesystem : containerInfo.SizeRootFs # in bytes
		mounts        : containerInfo.Mounts.filter (mount) ->
			hostPath: mount.Source, containerPath: mount.Destination, mode: mount.Mode
		labels: containerInfo.Config.Labels

	createContainer: ({ containerProps }, cb) ->
		log.info "Creating container #{containerProps.name} ..."

		@dockerClient.createContainer containerProps, (error, created) ->
			if error
				if error.statusCode is 409
					log.error "A container with the name #{containerProps.name} already exists"
				else unless error.statusCode in config.docker.retry.errorCodes
					log.error error.message

				return cb error

			log.info "Created container #{containerProps.name}"
			cb null, created

	startContainer: ({ id }, cb) ->
		log.info "Starting container #{id} ..."

		@dockerClient
			.getContainer id
			.start (error) ->
				if error
					log.error "Starting container `#{id}` failed: #{error.message}"
					return cb error

				cb null, "Container #{id} started correctly"

	restartContainer: ({ id }, cb) ->
		log.info "Restarting container #{id} ..."

		@dockerClient
			.getContainer id
			.restart (error) ->
				if error
					log.error "Restarting container `#{id}` failed: #{error.message}"
					return cb error

				cb null, "Container #{id} restarted correctly"

	removeContainer: ({ id, force = false }, cb) ->
		return cb() unless config.docker.allowContainerRemoval

		log.info "Removing container '#{id}'"

		@listContainers (error, containers) =>
			if error
				log.error "Error listing containers: #{error.message}"
				return cb error

			toRemove = containers.filter (c) -> (S c.name).contains id

			async.eachSeries toRemove, (c, cb) =>
				(@dockerClient.getContainer c.Id).remove { force }, (error) ->
					if error
						log.error "Error removing `#{id}`: #{error.message}"
					cb error
			, (error) ->
				if error
					log.error "Error in removing one of the containers"
				else
					log.info "Removed container `#{id}`"

				cb error

	getContainerLogs: ({ id }, cb) ->
		container = @dockerClient.getContainer id
		options   =
			stdout: true
			stderr: true
			tail:   100
			follow: false

		container.logs options, (error, logs) ->
			if error
				log.error "Error retrieving container logs for '#{id}'"
				return cb error

			unless logs
				error = new Error "No logs available for #{id}"
				log.warn error.message
				return cb new Error error

			logs = logs
				.split  "\n"
				.filter (line) -> not isEmpty line
				.map    (line) -> line.substr 8, line.length - 1

			cb null, logs

	getShortenedImageId: (id) ->
		return id unless id.startsWith "sha256:"

		id.substring 7, 7 + 12

module.exports = Docker
