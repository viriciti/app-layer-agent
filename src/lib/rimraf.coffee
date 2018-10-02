{ exec } = require "child_process"

rimraf = (file, cb) ->
	cb new Error "Missing file" unless file.length

	exec "rm -rf #{file}", (err, stdout, stderr) ->
		cb err

module.exports = rimraf