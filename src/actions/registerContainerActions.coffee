debug         = (require "debug") "app:registerContainerActions"
{ promisify } = require "util"

registerMethod = require "../helpers/registerMethod"

module.exports = ({ baseMethod, rpc, docker }) ->
	onRemoveContainer = ({ id, force = true }) ->
		debug "Removing container '#{id}'"
		await promisify(docker.removeContainer.bind docker) { id, force }

	onRestartContainer = ({ id }) ->
		debug "Restarting container '#{id}'"
		await promisify(docker.restartContainer.bind docker) { id }

	onFetchContainerLogs = ({ id }) ->
		debug "Fetching logs for container '#{id}'"
		await promisify(docker.getContainerLogs.bind docker) { id }

	registerMethod rpc, "#{baseMethod}/removeContainer",  onRemoveContainer
	registerMethod rpc, "#{baseMethod}/restartContainer", onRestartContainer
	registerMethod rpc, "#{baseMethod}/getContainerLogs", onFetchContainerLogs
