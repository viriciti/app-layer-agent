config            = require "config"
{ last, isArray } = require "lodash"

log          = require("./lib/Logger") "main"
Docker       = require "./lib/Docker"
AppUpdater   = require "./manager/AppUpdater"
StateManager = require "./manager/StateManager"
GroupManager = require "./manager/GroupManager"
TaskManager  = require "./manager/TaskManager"
Client       = require "./Client"

registerContainerActions = require "./actions/registerContainerActions"
registerImageActions     = require "./actions/registerImageActions"
registerDeviceActions    = require "./actions/registerDeviceActions"

log.info "Booting up manager ..."

do ->
	appUpdater   = undefined
	client       = new Client config.mqtt
	docker       = new Docker
	groupManager = new GroupManager
	state        = undefined
	taskManager  = undefined

	onCommand = (topic, payload) ->
		actionId                    = last topic.split "/"
		json                        = JSON.parse payload
		{ action, origin, payload } = json

		forked  = client.fork()
		topic   = "commands/#{origin}/#{actionId}/response"
		payload = [payload] unless isArray payload
		params  = [
			[
				config.mqtt.actions.baseTopic
				config.mqtt.clientId
				action
			].join "/"
			...payload
		]

		try
			console.log await taskManager.rpc.call ...params
			forked.publish topic, JSON.stringify
				action:     action
				data:       await taskManager.rpc.call ...params
				statusCode: "OK"
		catch error
			log.error error.message

			forked.publish topic, JSON.stringify
				action:     action
				data:       error
				statusCode: "ERROR"

	onInitialGroups = (topic, payload) ->
		client.subscribe "global/collections/+"

		state.sendStateToMqtt()
		state.sendNsState()

	onGroups = (topic, payload) ->
		groupManager.updateGroups payload

	onCollection = (topic, payload) ->
		appUpdater.handleCollection JSON.parse payload

	client
		.once "devices/{id}/groups", onInitialGroups
		.on "commands/{id}/#",       onCommand
		.on "devices/{id}/groups",   onGroups
		.on "global/collections/+",  onCollection

	await client.connect()
	log.info "Connected to the MQTT broker"

	taskManager = new TaskManager client.fork()
	state       = new StateManager client.fork(), docker, groupManager
	appUpdater  = new AppUpdater docker, state, groupManager

	await client.subscribe ["commands/{id}/+", "devices/{id}/groups"]

	actionOptions =
		appUpdater:   appUpdater
		docker:       docker
		rpc:          taskManager
		state:        state
		groupManager: groupManager

	state.notifyOnlineStatus()

	registerContainerActions actionOptions
	registerImageActions     actionOptions
	registerDeviceActions    actionOptions

	docker.on "logs", (data) ->
		return unless data

		state.throttledSendAppState() if data.action?.type is "container"
		state.publishLog data
