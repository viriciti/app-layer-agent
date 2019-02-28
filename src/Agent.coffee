config                               = require "config"
debug                                = (require "debug") "app:Agent"
kleur                                = require "kleur"
{ Observable }                       = require "rxjs"
{ isEqual, map, toPairs, fromPairs } = require "lodash"

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
getIPAddresses           = require "./helpers/getIPAddresses"

class Agent
	constructor: ->
		@isUpdatableOnGroups = false

	start: ->
		@client       = new Client config.mqtt
		@docker       = new Docker
		@groupManager = new GroupManager

		@client.connect()

		@client
			.on "connect", @onConnect
			.on "close",   @onClose

		@taskManager         = new TaskManager  @client.fork()
		@state               = new StateManager @client.fork(), @docker, @groupManager
		@appUpdater          = new AppUpdater   @docker,        @state,  @groupManager

		@observeTunnel()
		@registerActionHandlers()
		@client.subscribe ["devices/{id}/groups"]

	onConnect: =>
		log.info kleur.green "Connected to the MQTT broker"

		@taskManager
			.on "task", @onQueueUpdate
			.on "done", @onQueueUpdate

		@docker
			.on "logs", @onLogs

		log.warn "Waiting for groups before sending state ..."
		@client
			.once "devices/{id}/groups", (topic, payload) =>
				@client.subscribe "global/collections/+"

				@state.sendStateToMqtt()
				@state.sendNsState()
			.on "devices/{id}/groups",  @onGroups
			.on "global/collections/+", @onCollection

		@state.notifyOnlineStatus()

	onClose: =>
		log.warn "Connection closed"

		@taskManager
			.removeListener "task", @onQueueUpdate
			.removeListener "done", @onQueueUpdate

		@docker
			.removeListener "logs", @onLogs

		@client
			.removeListener "devices/{id}/groups",  @onGroups
			.removeListener "global/collections/+", @onCollection

	onGroups: (topic, payload) =>
		debug "Groups updated. Queue update: #{if @isUpdatableOnGroups then "yes" else "no"}"

		@groupManager.updateGroups JSON.parse payload
		@appUpdater.queueUpdate() if @isUpdatableOnGroups

	onCollection: (topic, payload) =>
		debug "Collection updated"

		@isUpdatableOnGroups = true unless @isUpdatableOnGroups
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

	observeTunnel: ->
		log.info "Observing network changes (tunnel only)"

		Observable
			.interval 1000
			.map ->
				interfaces = toPairs getIPAddresses()
				interfaces = interfaces.filter ([name]) ->
					name.startsWith "tun"

				fromPairs interfaces
			.distinctUntilChanged (prev, next) ->
				isEqual(
					Object.values prev
					Object.values next
				)
			.subscribe (interfaces) =>
				debug "VPN interfaces updated (one of #{Object.keys(interfaces).join ', '})"
				@state.sendSystemStateToMqtt()

	registerActionHandlers: ->
		log.info "Registering action handlers"

		actionOptions =
			appUpdater:   @appUpdater
			docker:       @docker
			groupManager: @groupManager
			state:        @state
			taskManager:  @taskManager

		registerContainerActions actionOptions
		registerImageActions     actionOptions
		registerDeviceActions    actionOptions

module.exports = Agent
