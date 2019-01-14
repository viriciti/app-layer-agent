{ last, isArray, map } = require "lodash"
config            = require "config"

log = require("./lib/Logger") "Agent"

Docker       = require "./lib/Docker"
AppUpdater   = require "./manager/AppUpdater"
StateManager = require "./manager/StateManager"
GroupManager = require "./manager/GroupManager"
TaskManager  = require "./manager/TaskManager"
Client       = require "./Client"
registerContainerActions = require "./actions/registerContainerActions"
registerImageActions     = require "./actions/registerImageActions"
registerDeviceActions    = require "./actions/registerDeviceActions"

class Agent
	start: ->
		@client       = new Client config.mqtt
		@docker       = new Docker
		@groupManager = new GroupManager

		await @client.connect()

		@taskManager = new TaskManager @client.fork()
		@state       = new StateManager @client.fork(), @docker, @groupManager
		@appUpdater  = new AppUpdater @docker, @state, @groupManager

		actionOptions =
			appUpdater:   @appUpdater
			docker:       @docker
			groupManager: @groupManager
			state:        @state
			taskManager:  @taskManager

		registerContainerActions actionOptions
		registerImageActions     actionOptions
		registerDeviceActions    actionOptions

		@taskManager
			.on "task", @onQueueUpdate
			.on "done", @onQueueUpdate

		@docker
			.on "logs", @onLogs

		@client
			.once "devices/{id}/groups", (topic, payload) =>
				@client.subscribe "global/collections/+"

				@state.sendStateToMqtt()
				@state.sendNsState()
			.on "commands/{id}/#",       @onCommand
			.on "devices/{id}/groups",   @onGroups
			.on "global/collections/+",  @onCollection

		await @state.notifyOnlineStatus()
		await @client.subscribe ["commands/{id}/+", "devices/{id}/groups"]

	onCommand: (topic, payload) =>
		actionId                    = last topic.split "/"
		json                        = JSON.parse payload
		{ action, origin, payload } = json

		forked  = @client.fork()
		topic   = "commands/#{origin}/#{actionId}/response"
		payload = [payload] unless isArray payload
		params  = [
			[
				config.mqtt.actions.baseTopic
				config.mqtt.clientId
				action
			]
				.join "/"
				.replace /\/{2,}/g, "/"
			...payload
		]

		try
			forked.publish topic, JSON.stringify
				action:     action
				data:       await @taskManager.rpc.call ...params
				statusCode: "OK"
		catch error
			log.error error.message

			forked.publish topic, JSON.stringify
				action:     action
				data:       error
				statusCode: "ERROR"

	onGroups: (topic, payload) =>
		@groupManager.updateGroups payload

	onCollection: (topic, payload) =>
		@appUpdater.handleCollection JSON.parse payload

	onQueueUpdate: =>
		@state.sendNsState queue: map @taskManager.getTasks(), (task) ->
			name:       task.name
			finished:   task.finished
			queuedOn:   task.queuedOn
			finishedAt: task.finishedAt

	onLogs: (data) =>
		return unless data

		@state.throttledSendAppState() if data.action?.type is "container"
		@state.publishLog data

	registerActionHandlers: ->
		appUpdater:   @appUpdater
		docker:       @docker
		groupManager: @groupManager
		state:        @state
		taskManager:  @taskManager

module.exports = Agent
