{ defaultTo } = require "lodash"
debug         = (require "debug") "app:helpers:registerMethod"

registeredMethods = []

module.exports = (rpc, method, fn) ->
	debug "Registering method '#{method}' ..."

	rpc.unregister method if registeredMethods.includes method
	registeredMethods.push method

	rpc.register method, (...params) ->
		debug "Executing method '#{method}' ..."

		response        = await fn.apply fn, params
		defaultResponse = ""

		defaultTo response, defaultResponse
