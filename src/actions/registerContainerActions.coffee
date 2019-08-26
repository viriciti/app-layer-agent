debug = (require "debug") "app:registerContainerActions"

registerFunction = require "../helpers/registerFunction"

module.exports = ({ taskManager, docker }) ->
	onRemoveContainer = ({ id, force = true }) ->
		debug "Removing container '#{id}'"
		await docker.removeContainer { id, force }

	onStartContainer = ({ id }) ->
		debug "Starting container '#{id}'"
		await docker.startContainer id

	onStopContainer = ({ id }) ->
		debug "Stopping container '#{id}'"
		await docker.stopContainer id

	onRestartContainer = ({ id }) ->
		debug "Restarting container '#{id}'"
		await docker.restartContainer id

	onFetchContainerLogs = ({ id }) ->
		debug "Fetching logs for container '#{id}'"
		await docker.getContainerLogs id

	registerFunction
		fn:          onRemoveContainer
		name:        "removeContainer"
		taskManager: taskManager

	registerFunction
		fn:          onStartContainer
		name:        "startContainer"
		taskManager: taskManager

	registerFunction
		fn:          onStopContainer
		name:        "stopContainer"
		taskManager: taskManager

	registerFunction
		fn:          onRestartContainer
		name:        "restartContainer"
		taskManager: taskManager

	registerFunction
		fn:          onFetchContainerLogs
		name:        "getContainerLogs"
		taskManager: taskManager
		sync:        true
