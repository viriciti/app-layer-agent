{ promisify } = require "util"
debug         = (require "debug") "app:registerImageActions"

registerFunction = require "../helpers/registerFunction"

module.exports = ({ rpc, docker }) ->
	onRemoveImage = ({ id, force = true }) ->
		debug "Removing image '#{id}'"
		await promisify(docker.removeImage.bind docker) { id, force }

	registerFunction
		fn:   onRemoveImage
		name: "removeImage"
		rpc:  rpc
