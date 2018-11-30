{ omit }   = require "lodash"
async      = require "async"
config     = require "config"
debug      = (require "debug") "app:main"
devicemqtt = require "device-mqtt"

log          = require("./lib/Logger") "main"
Docker       = require "./lib/Docker"
AppUpdater   = require './manager/AppUpdater'
StateManager = require './manager/StateManager'

mqttSocket    = null
getMqttSocket = -> mqttSocket

lastWill =
	topic:   "devices/#{config.host}/status"
	payload: "offline"

queue = async.queue (task, cb) ->
	log.info "Executing action: `#{task.name}`"
	task.fn cb

updateTodos = ->
	[]
		.concat queue.workersList().map    (item) -> item.data.name
		.concat queue._tasks.toArray().map (item) -> item.name

log.info "Booting up manager..."

docker      = new Docker   config.docker
state       = StateManager config, getMqttSocket, docker
appUpdater  = AppUpdater   docker, state
{ execute } = require("./manager/actionsMap") docker, state, appUpdater

options = config.mqtt
options = omit options, "tls" if config.development
client  = devicemqtt options

log.info "Connecting to #{if options.tls? then 'mqtts' else 'mqtt'}://#{options.host}:#{options.port} ..."
client.on "connected", (socket) ->
	log.info "Connected to the MQTT broker"

	mqttSocket = socket

	state.notifyOnlineStatus()
	state.throttledSendState()
	state.sendNsState()

	_onAction = (action, payload, reply) ->
		log.info "New action received: \nAction: #{action}\nPayload: #{JSON.stringify payload}"
		debug "Action queue length: #{queue.length()}"

		task =
			name: action
			fn: (cb) ->
				debug "Action queue length: #{queue.length()}"
				debug "Action `#{action}` being executed"
				execute { action, payload }, (error, result) ->
					debug "Received an error: #{error.message}" if error
					debug "Received result for action: #{action} - #{result}"

					if error
						return reply.send type: "error", data: error.message, (mqttErr, ack) ->
							log.error "An error occurred sending the message: #{error.message}" if mqttErr
							return cb()

					reply.send type: "success", data: result, (error, ack) ->
						log.error "An error occurred sending the message: #{error.message}" if error

						# TODO give actions some sort of meta so we can act accordingly when they error/succeed
						return cb() if action in [
							"getContainerLogs"
							"refreshState"
						]

						debug "Action `#{action}` kicking state"
						# TODO No remove...
						state.throttledSendState()

						cb()

		queue.push task, (error) ->
			debug "Action queue length: #{queue.length()}"
			state.publishNamespacedState queue: updateTodos()

			if error
				state.updateFinishedQueueList
					exitState: "error"
					message:   error.message
					name:      task.name
					timestamp: Date.now()
				return log.error "Error processing action `#{action}`: #{error.message}"

			log.info "Action #{action} completed"
			state.updateFinishedQueueList
				exitState: "success"
				message:   "done"
				name:      task.name
				timestamp: Date.now()

		state.publishNamespacedState queue: updateTodos()

	_onSocketError = (error) ->
		log.error "MQTT socket error!: #{error.message}" if error

	socket
		.on   "action",               _onAction
		.on   "error",                _onSocketError
		.on   "global:collection",    appUpdater.handleCollection
		.once "disconnected", (reason) ->
			log.warn "Disconnected from MQTT"

			socket.removeListener "action",               _onAction
			socket.removeListener "error",                _onSocketError
			socket.removeListener "global:collection",    appUpdater.handleCollection

			# HACK:
			throw new Error "Disconnected! Killing myself!"

docker.on "logs", (data) ->
	return unless data # The logsparser currently returns undefined if it can't parse the logs... meh

	state.throttledSendAppState() if data.action?.type is "container"
	state.publishLog data

debug "Connecting to MQTT at #{config.mqtt.host}:#{config.mqtt.port}"
client
	.on "error", (error) ->
		log.error "MQTT client error occurred: #{error.message}"
		throw error if error.message?.includes "EAI_AGAIN"
	.on "reconnecting", (error) ->
		log.info "Reconnecting ..."
	.connect lastWill
