path          = require "path"
{ promisify } = require "util"

debug = (require "debug") "app:registerContainerActions"

module.exports = ({ baseMethod, rpc, docker }) ->
	onRemoveContainer = ({ id, force = true }) ->
		debug "Removing container '#{id}'"
		await promisify(docker.removeContainer.bind docker) { id, force }

	onRestartContainer = ({ id }) ->
		debug "Restarting container '#{id}'"
		await promisify(docker.restartContainer.bind docker) { id }

	onFetchContainerLogs = ({ id }) ->
		debug "Fetching logs for container '#{id}'"
		await promisify(docker.getContainerLogs.bind docker) { id, numOfLogs: 100 }

	rpc
		.register path.join(baseMethod, "removeContainer"),  onRemoveContainer
		.register path.join(baseMethod, "restartContainer"), onRestartContainer
		.register path.join(baseMethod, "getContainerLogs"), onFetchContainerLogs
