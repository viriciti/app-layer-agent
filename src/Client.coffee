MQTTPattern                       = require "mqtt-pattern"
mqtt                              = require "mqtt"
{ EventEmitter }                  = require "events"
{ omit, every, isArray, forEach } = require "lodash"
{ promisify }                     = require "util"

log = require("./lib/Logger") "Client"

class Client extends EventEmitter
	constructor: (@options) ->
		super()

		@clientId = @options.clientId
		@options  = { ...@options, ...@options.extraOptions, will: @getWill() }
		@options  = omit @options, "tls" unless every @options.tls
		@options  = omit @options, "extraOptions"

		@events           = []
		@subscribedTopics = []

	connect: ->
		new Promise (resolve) =>
			@mqtt = mqtt.connect @options

			@mqtt
				.once "connect",     resolve
				.on "packetreceive", @onPacket
				.on "error",         @onError
				.on "reconnect",     @onReconnect
				.on "offline",       @onOffline
				.on "close",         @onClose

	onPacket: (packet) =>
		return unless packet
		return unless packet?.topic
		return unless packet?.cmd is "publish"

		forEach @_events, (fn, topic) =>
			payload  = packet.payload.toString()
			expanded = @expandTopic topic
			return unless MQTTPattern.matches expanded, packet.topic

			@emit topic, expanded, payload

	onError: (error) ->
		log.error "Could not connect to the MQTT broker: #{error.message}"

	onReconnect: ->
		log.warn "Reconnecting to the MQTT broker ..."

	onOffline: ->
		log.warn "Disconnected"

	onClose: (reason) =>
		@mqtt
			.removeListener "packetreceive", @onPacket
			.removeListener "error",         @onError
			.removeListener "reconnect",     @onReconnect
			.removeListener "offline",       @onOffline
			.removeListener "close",         @onClose

	getWill: ->
		topic:   "devices/#{@clientId}/status"
		payload: "offline"
		retain:  true

	expandTopic: (topic) =>
		topic.replace /{id}/g, @clientId

	fork: ->
		throw new Error "You must connect before you can fork the MQTT client" unless @mqtt
		@mqtt

	subscribe: (topics) ->
		await @connect() unless @mqtt

		topics = [topics] unless isArray topics
		topics = topics.map @expandTopic

		promisify(@mqtt.subscribe.bind @mqtt) topics

module.exports = Client
