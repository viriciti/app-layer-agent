mqtt                           = require "mqtt"
{ omit, every, isArray, once } = require "lodash"
{ promisify }                  = require "util"
{ EventEmitter }               = require "events"

log = require("./lib/Logger") "Client"

class Client extends EventEmitter
	constructor: (@options) ->
		super()

		@clientId = @options.clientId
		@options  = { ...@options, ...@options.extraOptions, will: @getWill() }
		@options  = omit @options, "tls" unless every @options.tls
		@options  = omit @options, "extraOptions"

		@subscribedTopics = []

	connect: ->
		new Promise (resolve) =>
			@mqtt = mqtt.connect @options

			@mqtt
				.once "connect", resolve
				.on "message",   @onMessage
				.on "error",     @onError
				.on "reconnect", @onReconnect
				.on "offline",   @onOffline
				.on "close",     @onClose

	onMessage: (topic) ->
		console.log "Topic: #{topic}"

	onError: (error) ->
		log.error "Could not connect to the MQTT broker: #{error.message}"

	onReconnect: ->
		log.warn "Reconnecting to the MQTT broker ..."

	onOffline: (reason) ->
		log.warn "Disconnected"

	onClose: ->
		@mqtt
			.removeListener "message",   @onMessage
			.removeListener "error",     @onError
			.removeListener "reconnect", @onReconnect
			.removeListener "offline",   @onOffline
			.removeListener "close",     @onClose

	getWill: ->
		topic:   "devices/#{@clientId}/status"
		payload: "offline"
		retain:  true

	fork: ->
		@mqtt

	subscribe: (topics) ->
		topics = [topics] unless isArray topics
		topics = topics.map (topic) =>
			topic.replace /{id}/g, @clientId

		promisify(@mqtt.subscribe.bind @mqtt) topics

	subscribeOnce: once (state) =>
		@mqtt.subscribe "global/collections/+"

		state.sendStateToMqtt()
		state.sendNsState()

module.exports = Client
