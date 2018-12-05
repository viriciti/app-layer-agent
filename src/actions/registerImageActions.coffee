{ promisify } = require "util"
debug         = (require "debug") "app:registerImageActions"

registerMethod = require "../helpers/registerMethod"

module.exports = ({ baseMethod, rpc, docker }) ->
	onRemoveImage = ({ id, force = true }) ->
		debug "Removing image '#{id}'"
		await promisify(docker.removeImage.bind docker) { id, force }

	registerMethod rpc, "#{baseMethod}/removeImage", onRemoveImage
