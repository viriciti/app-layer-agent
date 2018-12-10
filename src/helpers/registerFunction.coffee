debug = (require "debug") "app:helpers:registerFunction"

registeredFunctions = []

module.exports = (rpc, name, fn) ->
	# remove duplicate forward slashes
	name = name.replace /\/{2,}/g, "/"

	debug "Registering function '#{name}' ..."

	rpc.unregister name if registeredFunctions.includes name
	registeredFunctions.push name

	rpc.register name, (...params) ->
		debug "Executing function '#{name}' ..."

		try
			status: "OK"
			data:   await fn.apply fn, params
		catch error
			status: "ERROR"
			data:   error.message
		finally
			debug "Function '#{name}' executed"
