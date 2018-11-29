{ exec } = require "child_process"

module.exports = (file, cb) ->
	return cb new Error "Missing file" unless file.length

	exec "rm -rf #{file}", cb
