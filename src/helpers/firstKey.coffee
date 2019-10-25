{ first, isPlainObject } = require "lodash"

module.exports = (object) ->
	throw new Error "Cannot read first key from non-object" unless isPlainObject object

	first Object.keys object
