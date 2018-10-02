debug = (require "debug") "app:actions:container"

log = (require "../lib/Logger") "container actions"

module.exports = (docker, state) ->
	removeContainer = ({ id, force = true }, cb) ->
		log.info "Remove container `#{id}`"

		docker.removeContainer { id, force }, (error, result) ->
			if error
				log.error "Error removing container: `#{error.message}`"
			else
				log.info "Container `#{id}` removed"

			cb error, result

	restartContainer = ({ id }, cb) ->
		log.info "Restarting container `#{id}`"

		docker.restartContainer { id }, (error, result) ->
			if error
				log.error "Error restarting container: `#{error.message}`"
			else
				log.info "Container `#{id}` restarted"

			cb error, result

	getContainerLogs = ({ id, numOfLogs }, cb) ->
		debug "Geting container logs"

		docker.getContainerLogs { id, numOfLogs }, (error, result) ->
			if error
				log.error "Error restarting container: `#{error.message}`"
			else
				debug "Container logs retrieved"

			cb error, result

	return {
		removeContainer,
		restartContainer,
		getContainerLogs
	}
