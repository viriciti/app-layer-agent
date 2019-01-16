debug = (require "debug") "app:registerImageActions"

registerFunction = require "../helpers/registerFunction"

module.exports = ({ taskManager, docker }) ->
	onRemoveImage = ({ id, force = true }) ->
		debug "Removing image '#{id}'"
		await docker.removeImage { id, force }

	registerFunction
		fn:          onRemoveImage
		name:        "removeImage"
		taskManager: taskManager
