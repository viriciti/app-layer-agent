{ promisify } = require "util"
debug         = (require "debug") "app:registerImageActions"

registerFunction = require "../helpers/registerFunction"

module.exports = ({ baseName, rpc, docker }) ->
	onRemoveImage = ({ id, force = true }) ->
		debug "Removing image '#{id}'"
		await promisify(docker.removeImage.bind docker) { id, force }

	registerFunction rpc, "#{baseName}/removeImage", onRemoveImage
