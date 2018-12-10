RPC                     = require "mqtt-json-rpc"
config                  = require "config"
mqtt                    = require "mqtt"
{ omit, last, isArray } = require "lodash"

log          = require("./lib/Logger") "main"
Docker       = require "./lib/Docker"
AppUpdater   = require "./manager/AppUpdater"
StateManager = require "./manager/StateManager"

registerContainerActions = require "./actions/registerContainerActions"
registerGroupActions     = require "./actions/registerGroupActions"
registerImageActions     = require "./actions/registerImageActions"
registerDeviceActions    = require "./actions/registerDeviceActions"

will =
	topic:   "devices/#{config.mqtt.clientId}/status"
	payload: "offline"
	retain:  true

log.info "Booting up manager ..."

options      = config.mqtt
options      = { ...options, will }
options      = omit options, "tls" if config.development
client       = mqtt.connect options

rpc          = new RPC client
docker       = new Docker
state        = new StateManager client, docker
appUpdater   = new AppUpdater   docker, state

mqttProtocol  = if options.tls? then "mqtts" else "mqtt"
mqttUrl       = "#{mqttProtocol}://#{options.host}:#{options.port}"
actionOptions =
		appUpdater: appUpdater
		baseName: "#{config.mqtt.actions.baseTopic}#{options.clientId}"
		docker:     docker
		rpc:        rpc
		state:      state

log.info "Connecting to #{mqttUrl} as #{options.clientId} ..."
onConnect = ->
	log.info "Connected to the MQTT broker"

	client
		.on "message",   onMessage
		.on "error",     onError
		.on "reconnect", onReconnect
		.on "offline",   onOffline
		.on "close",     onClose

	state.notifyOnlineStatus()
	state.throttledSendState()
	state.sendNsState()

	registerContainerActions actionOptions
	registerImageActions     actionOptions
	registerGroupActions     actionOptions
	registerDeviceActions    actionOptions

	# support legacy actions (commands)
	client.subscribe [
		"commands/#{options.clientId}/+"
		"global/collections/+"
	]

onMessage = (topic, message) ->
	if topic.startsWith "commands/#{options.clientId}"
		actionId                    = last topic.split "/"
		json                        = JSON.parse message.toString()
		{ action, origin, payload } = json

		topic   = "commands/#{origin}/#{actionId}/response"
		payload = [payload] unless isArray payload
		params  = [
			"#{config.mqtt.actions.baseTopic}#{options.clientId}/#{action}"
			...payload
		]

		rpc
			.call
			.apply rpc, params
			.then (result) ->
				client.publish topic, JSON.stringify
					action:      action
					data:        result
					statusCode: "OK"
			.catch (error) ->
				log.error error.message

				client.publish topic, JSON.stringify
					action:     action
					data:       error
					statusCode: "ERROR"
	else if topic.startsWith "global/collections/"
		appUpdater.handleCollection JSON.parse message.toString()

onError = (error) ->
	log.error "Could not connect to the MQTT broker: #{error.message}"

onReconnect = ->
	log.warn "Reconnecting to the MQTT broker ..."

onOffline = (reason) ->
	log.warn "Disconnected ..."

onClose = ->
	client
		.removeListener "message",   onMessage
		.removeListener "error",     onError
		.removeListener "reconnect", onReconnect
		.removeListener "close",     onClose

client.on "connect", onConnect

docker.on "logs", (data) ->
	return unless data

	state.throttledSendAppState() if data.action?.type is "container"
	state.publishLog data
