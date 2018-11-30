path          = require "path"
{ promisify } = require "util"

debug = (require "debug") "app:registerImageActions"

module.exports = ({ baseMethod, rpc, docker }) ->
	onRemoveImage = ({ id, force = true }) ->
		debug "Removing image '#{id}'"
		await promisify(docker.removeImage.bind docker) { id, force }

	rpc.register path.join(baseMethod, "onRemoveImage"), onRemoveImage
