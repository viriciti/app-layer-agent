debug = (require "debug") "app:helpers:registerFunction"
config = require "config"

module.exports = ({ rpc, name, fn, sync = false }) ->
	name = [
		config.mqtt.actions.baseTopic
		config.mqtt.clientId
		name
	].join "/"

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
