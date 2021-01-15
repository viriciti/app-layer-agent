class DockerLogsParser
	constructor: (@docker) ->

	# coffeelint: disable=cyclomatic_complexity
	parseLogs: (logs) ->
		return @_handleDyingContainer logs if logs.status is "die"

		switch logs.Type
			when "image"
				switch logs.Action
					when "pull"   then @_handlePullImageLogs   logs
					when "untag"  then @_handleUntagImageLogs  logs
					when "tag"    then @_handleTagImageLogs    logs
					when "delete" then @_handleDeleteImageLogs logs
			when "container"
				switch logs.Action
					when "create"        then @_handleCreateContainerLogs  logs
					when "start"         then @_handleStartContainerLogs   logs
					when "stop"          then @_handleStopContainerLogs    logs
					when "destroy"       then @_handleDestroyContainerLogs logs
					else
						@_handleHealthLogs logs if -1 < logs.Action.indexOf "health_status"

	generateMessage: ({ raw, message, type = "info" }) ->
		{ Actor, Action, Type, time } = raw
		{ Attributes }                = Actor
		{ name, image, exitCode }     = Attributes

		health = undefined
		health = Action.split(": ")[1] if -1 < Action.indexOf "health_status"
		type   = "warning" if health is "unhealthy"

		message: (message
			.replace /{name}/g,     name
			.replace /{image}/g,    image
			.replace /{health}/g,   health
			.replace /{exitCode}/g, exitCode
		)
		type:    type
		time:    time * 1000
		action:
			action: Action
			name:   name
			type:   Type
		health: health
		id:     Actor.ID

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
			message: "Container {name} started"

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

	_handleHealthLogs: (logs) ->
		@generateMessage
			raw:     logs
			message: "Container {name} health is {health}"

	_handleDyingContainer: (logs) ->
		@generateMessage
			raw:     logs
			message: "Container {name} has died with exit code {exitCode}"
			type:    "warning"

module.exports = DockerLogsParser
