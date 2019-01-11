debug = (require "debug") "app:helpers:registerFunction"

module.exports = (rpc, name, fn) ->
	# remove duplicate forward slashes
	name = name.replace /\/{2,}/g, "/"

	debug "Registering function '#{name}' ..."

	rpc.register name, (...params) ->
		debug "Executing function '#{name}' ..."

		rpc.addTask
			name:   name
			fn:     fn
			params: params

		status: "ACK"
