{ Writable } = require "stream"

class LayerFixer extends Writable
	constructor: (@regex) ->
		super objectMode: true

	_write: (data, enc, cb) =>
		return cb() unless data.error

		parsed = @regex.exec data.error

		return cb new Error data.error unless parsed

		conflictingDirectory = parsed.shift().trim()

		return cb new Error data.error unless conflictingDirectory

		error = new Error "Removing conflicting directory: #{conflictingDirectory}"
		error.conflictingDirectory = conflictingDirectory

		cb error

module.exports = LayerFixer
