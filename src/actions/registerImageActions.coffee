{ promisify } = require "util"
debug         = (require "debug") "app:registerImageActions"

registerFunction = require "../helpers/registerFunction"

module.exports = ({ taskManager, docker }) ->
	onRemoveImage = ({ id, force = true }) ->
		debug "Removing image '#{id}'"
		await promisify(docker.removeImage.bind docker) { id, force }

	registerFunction
		fn:          onRemoveImage
		name:        "removeImage"
		taskManager: taskManager
