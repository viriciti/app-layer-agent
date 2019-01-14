debug = (require "debug") "app:helpers:registerFunction"

module.exports = ({ rpc, name, fn, sync = false }) ->
	# remove duplicate forward slashes
	name = name.replace /\/{2,}/g, "/"

	debug "Registering function '#{name}' ..."

	rpc.register name, (...params) ->
		debug "Executing function '#{name}' ..."

		if sync
			fn ...params
		else
			rpc.addTask
				name:   name
				fn:     fn
				params: params

			status: "ACK"
