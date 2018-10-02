debug = (require "debug") "app:docker-logs"

log = (require "../lib/Logger") "DockerLogsParser"

###
The DockerLogsParser class parses the events messages
coming from the docker daemon activity.
Currently, is not possible to parse correctly the delete
image and destroy container events,
since the information about images and containers
are no longer available after removing them.
###

class DockerLogsParser
	constructor: (@docker) ->

	parseLogs: (logs) =>
		if (logs.status is "die")
			return @_handleDyingContainer logs

		switch logs.Type
			when "image"
				switch logs.Action
					when "pull" then @_handlePullImageLogs logs
					when "untag" then @_handleUntagImageLogs logs
					when "tag" then @_handleTagImageLogs logs
					when "delete" then @_handleDeleteImageLogs logs
			when "container"
				switch logs.Action
					when "create" then @_handleCreateContainerLogs logs
					when "start" then @_handleStartContainerLogs logs
					when "stop" then @_handleStopContainerLogs logs
					when "destroy" then @_handleDestroyContainerLogs logs

	_handlePullImageLogs: (logs) ->
		image = logs.Actor.ID
		time = logs.time * 1000
		return { message: "Pulled image #{image}", time, type: "info" }

	_handleUntagImageLogs: (logs) ->
		imageID = (logs.Actor.ID.split ":")[1]
		time = logs.time * 1000
		return { message: "An image has been untagged", time, type: "info" }

	_handleTagImageLogs: (logs) ->
		image = (logs.Actor.Attributes.name.split ":")[0]
		imageTag = (logs.Actor.Attributes.name.split ":")[1]
		time = logs.time * 1000
		return { message: "Tagged image #{image} with tag #{imageTag}", time, type: "info" }

	_handleDeleteImageLogs: (logs) ->
		imageID = (logs.Actor.ID.split ":")[1]
		time = logs.time * 1000
		return { message: "An image has been removed", time, type: "info" }

	_handleStartContainerLogs: (logs) ->
		containerName = logs.Actor.Attributes.name
		time = logs.time * 1000
		return { message: "Started container #{containerName}", time, type: "info" }

	_handleCreateContainerLogs: (logs) ->
		fromImage = logs.Actor.Attributes.image
		containerName = logs.Actor.Attributes.name
		time = logs.time * 1000
		return {
			message: "Created container #{containerName} from image #{fromImage}"
			time
			type: "info"
		}

	_handleStopContainerLogs: (logs) ->
		containerName = logs.Actor.Attributes.name
		time = logs.time * 1000
		return { message: "Stopped container #{containerName}", time, type: "info" }

	_handleDestroyContainerLogs: (logs) ->
		time = logs.time * 1000
		return { message: "A container has been destroyed", time, type: "info" }


	_handleDyingContainer: (logs) ->
		time = logs.time * 1000
		return { message: "Container #{logs.Actor.Attributes.name} has died!", time, type: "warning" }

module.exports = DockerLogsParser
