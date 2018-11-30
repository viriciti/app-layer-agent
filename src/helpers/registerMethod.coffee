debug = (require "debug") "app:helpers:registerMethod"

registeredMethods = []

module.exports = (rpc, method, fn) ->
	debug "Registering method '#{method}' ..."

	rpc.unregister method if registeredMethods.includes method
	registeredMethods.push method

	rpc.register method, (...params) ->
		debug "Executing method '#{method}' ..."

		try
			status: "OK", data: await fn.apply fn, params
		catch error
			status: "ERROR", data: error.message
