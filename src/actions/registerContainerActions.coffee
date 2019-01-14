debug         = (require "debug") "app:registerContainerActions"
{ promisify } = require "util"

registerFunction = require "../helpers/registerFunction"

module.exports = ({ taskManager, docker }) ->
	onRemoveContainer = ({ id, force = true }) ->
		debug "Removing container '#{id}'"
		await promisify(docker.removeContainer.bind docker) { id, force }

	onRestartContainer = ({ id }) ->
		debug "Restarting container '#{id}'"
		await promisify(docker.restartContainer.bind docker) { id }

	onFetchContainerLogs = ({ id }) ->
		debug "Fetching logs for container '#{id}'"
		await promisify(docker.getContainerLogs.bind docker) { id }

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
