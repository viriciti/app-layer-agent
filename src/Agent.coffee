{ last, isArray, map } = require "lodash"
config                 = require "config"

log = require("./lib/Logger") "Agent"

Docker                   = require "./lib/Docker"
AppUpdater               = require "./manager/AppUpdater"
StateManager             = require "./manager/StateManager"
GroupManager             = require "./manager/GroupManager"
TaskManager              = require "./manager/TaskManager"
Client                   = require "./Client"
registerContainerActions = require "./actions/registerContainerActions"
registerImageActions     = require "./actions/registerImageActions"
registerDeviceActions    = require "./actions/registerDeviceActions"

class Agent
	start: ->
		@client       = new Client config.mqtt
		@docker       = new Docker
		@groupManager = new GroupManager

		@client.connect()

		@client
			.on "connect", @onConnect
			.on "close",   @onClose

		@taskManager = new TaskManager  @client.fork()
		@state       = new StateManager @client.fork(), @docker, @groupManager
		@appUpdater  = new AppUpdater   @docker,        @state,  @groupManager

		actionOptions =
			appUpdater:   @appUpdater
			docker:       @docker
			groupManager: @groupManager
			state:        @state
			taskManager:  @taskManager

		registerContainerActions actionOptions
		registerImageActions     actionOptions
		registerDeviceActions    actionOptions

		@client.subscribe ["commands/{id}/+", "devices/{id}/groups"]

	onConnect: =>
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
			.on "commands/{id}/#",      @onCommand
			.on "devices/{id}/groups",  @onGroups
			.on "global/collections/+", @onCollection

		@state.notifyOnlineStatus()

	onClose: =>
		@taskManager
			.removeListener "task", @onQueueUpdate
			.removeListener "done", @onQueueUpdate

		@docker
			.removeListener "logs", @onLogs

		@client
			.removeListener "commands/{id}/#",      @onCommand
			.removeListener "devices/{id}/groups",  @onGroups
			.removeListener "global/collections/+", @onCollection

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
		@groupManager.updateGroups JSON.parse payload

	onCollection: (topic, payload) =>
		@appUpdater.handleCollection JSON.parse payload

	onQueueUpdate: =>
		@state.sendNsState queue: map @taskManager.getTasks(), (task) ->
			Object.assign {},
				name:       task.name
				finished:   task.finished
				queuedOn:   task.queuedOn
				finishedAt: task.finishedAt
				status:     task.status
			,
				error: task.error if task.error

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
