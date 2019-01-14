debug         = (require "debug") "app:registerContainerActions"
{ promisify } = require "util"

registerFunction = require "../helpers/registerFunction"

module.exports = ({ baseName, rpc, docker }) ->
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
		fn:   onRemoveContainer
		name: "#{baseName}/removeContainer"
		rpc:  rpc

	registerFunction
		fn:   onRestartContainer
		name: "#{baseName}/restartContainer"
		rpc:  rpc

	registerFunction
		fn:   onFetchContainerLogs
		name: "#{baseName}/getContainerLogs"
		rpc:  rpc
		sync: true
