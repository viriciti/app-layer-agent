log = (require "../lib/Logger") "images actions"

module.exports = (docker, state) ->
	removeImage = ({ id, force = true }, cb) ->
		log.info "Removing image `#{id}`"

		docker.removeImage { id, force }, (error, result) ->
			if error
				log.error "Error removing image: `#{error.message}`"
			else
				log.info "Image removed"

			cb error, result

	return { removeImage }
