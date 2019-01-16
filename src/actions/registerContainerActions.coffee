debug = (require "debug") "app:registerContainerActions"

registerFunction = require "../helpers/registerFunction"

module.exports = ({ taskManager, docker }) ->
	onRemoveContainer = ({ id, force = true }) ->
		debug "Removing container '#{id}'"
		await docker.removeContainer { id, force }

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
		fn:          onRestartContainer
		name:        "restartContainer"
		taskManager: taskManager

	registerFunction
		fn:          onFetchContainerLogs
		name:        "getContainerLogs"
		taskManager: taskManager
		sync:        true
