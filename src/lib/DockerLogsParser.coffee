class DockerLogsParser
	constructor: (@docker) ->

	parseLogs: (logs) ->
		if (logs.status is "die")
			return @_handleDyingContainer logs

		switch logs.Type
			when "image"
				switch logs.Action
					when "pull"   then @_handlePullImageLogs   logs
					when "untag"  then @_handleUntagImageLogs  logs
					when "tag"    then @_handleTagImageLogs    logs
					when "delete" then @_handleDeleteImageLogs logs
			when "container"
				switch logs.Action
					when "create"  then @_handleCreateContainerLogs  logs
					when "start"   then @_handleStartContainerLogs   logs
					when "stop"    then @_handleStopContainerLogs    logs
					when "destroy" then @_handleDestroyContainerLogs logs

	generateMessage: ({ raw, message, type = "info" }) ->
		{ Actor, Action, Type, time } = raw
		{ Attributes }                = Actor
		{ name, image }               = Attributes

		message: (message
			.replace /{name}/g,  name
			.replace /{image}/g, image
		)
		type:    type
		time:    time * 1000
		action:
			action: Action
			name:   name
			type:   Type

	_handlePullImageLogs: (logs) ->
		@generateMessage
			raw:     logs
			message: "Pulled image {name}"

	_handleUntagImageLogs: (logs) ->
		@generateMessage
			raw:     logs
			message: "An image has been untagged"

	_handleTagImageLogs: (logs) ->
		@generateMessage
			raw:     logs
			message: "Image tagged: {name}"

	_handleDeleteImageLogs: (logs) ->
		@generateMessage
			raw:     logs
			message: "An image has been removed"

	_handleStartContainerLogs: (logs) ->
		@generateMessage
			raw:     logs
			message: "Started container {name}"

	_handleCreateContainerLogs: (logs) ->
		@generateMessage
			raw:     logs
			message: "Created container {name} from {image}"

	_handleStopContainerLogs: (logs) ->
		@generateMessage
			raw:     logs
			message: "Container {name} stopped"

	_handleDestroyContainerLogs: (logs) ->
		@generateMessage
			raw:     logs
			message: "A container has been destroyed"

	_handleDyingContainer: (logs) ->
		@generateMessage
			raw:     logs
			message: "Container {name} has died"
			type:    "warning"

module.exports = DockerLogsParser
