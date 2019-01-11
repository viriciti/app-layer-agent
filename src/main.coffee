RPC                                  = require "mqtt-json-rpc"
config                               = require "config"
{ last, isArray, once } = require "lodash"

log            = require("./lib/Logger") "main"
Docker         = require "./lib/Docker"
AppUpdater     = require "./manager/AppUpdater"
StateManager   = require "./manager/StateManager"
GroupManager   = require "./manager/GroupManager"
Client         = require "./Client"

registerContainerActions = require "./actions/registerContainerActions"
registerImageActions     = require "./actions/registerImageActions"
registerDeviceActions    = require "./actions/registerDeviceActions"

log.info "Booting up manager ..."

do ->
	client       = new Client config.mqtt

	await client.connect()
	await client.subscribe ["commands/{id}/+", "devices/{id}/groups"]

	rpc          = new RPC client.fork()
	docker       = new Docker
	groupManager = new GroupManager
	state        = new StateManager client.fork(), docker, groupManager
	appUpdater   = new AppUpdater   docker, state, groupManager

	actionOptions =
		appUpdater:   appUpdater
		baseName:     "#{config.mqtt.actions.baseTopic}#{config.mqtt.clientId}"
		docker:       docker
		rpc:          rpc
		state:        state
		groupManager: groupManager

	subscribeToCollections = once ->
		client.subscribe "global/collections/+"

	sendInitialState = once ->
		state.sendStateToMqtt()
		state.sendNsState()

	log.info "Connected to the MQTT broker"

	state.notifyOnlineStatus()

	registerContainerActions actionOptions
	registerImageActions     actionOptions
	registerDeviceActions    actionOptions

	onMessage = (topic, message) ->
		if topic.startsWith "commands/#{config.mqtt.clientId}"
			actionId                    = last topic.split "/"
			json                        = JSON.parse message.toString()
			{ action, origin, payload } = json

			topic   = "commands/#{origin}/#{actionId}/response"
			payload = [payload] unless isArray payload
			params  = [
				"#{actionOptions.baseName}/#{action}"
				...payload
			]

			try
				client.publish topic, JSON.stringify
					action:     action
					data:       await rpc.call [rpc, params]...
					statusCode: "OK"
			catch error
				log.error error.message

				client.publish topic, JSON.stringify
					action:     action
					data:       error
					statusCode: "ERROR"
		else if topic is "devices/#{config.mqtt.clientId}/groups"
			groupManager.updateGroups JSON.parse message.toString()
			subscribeToCollections()
			sendInitialState()
		else if topic.startsWith "global/collections"
			appUpdater.handleCollection JSON.parse message.toString()


	client
		.fork()
		.on "message", onMessage

	docker.on "logs", (data) ->
		return unless data

		state.throttledSendAppState() if data.action?.type is "container"
		state.publishLog data
