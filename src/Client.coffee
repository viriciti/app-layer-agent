MQTTPattern                             = require "mqtt-pattern"
config                                  = require "config"
fs                                      = require "fs"
mqtt                                    = require "async-mqtt"
{ EventEmitter }                        = require "events"
{ omit, every, isArray, forEach, uniq } = require "lodash"
kleur                                   = require "kleur"

log = require("./lib/Logger") "Client"

class Client extends EventEmitter
	constructor: ->
		super()

		@options  = config.mqtt
		@clientId = @options.clientId
		@options  = { ...@options, ...@options.extraOptions, will: @getWill() }
		@options  = omit @options, "tls" unless @isTLSEnabled()
		@options  = omit @options, "extraOptions"

		@subscribedTopics = []

	isTLSEnabled: ->
		@options.tls and every @options.tls

	constructURL: ->
		protocol = "mqtt"
		protocol = "mqtts" if @options.tls
		host     = @options.host
		port     = @options.port

		"#{protocol}://#{host}:#{port}"

	withTLS: (options) ->
		return options unless @isTLSEnabled()

		options = Object.assign {},
			key:  fs.readFileSync options.tls.key
			ca:   fs.readFileSync options.tls.ca
			cert: fs.readFileSync options.tls.cert
		, options

		options = omit options, "tls"

	connect: ->
		url     = @constructURL()
		options = @withTLS @options

		if @isTLSEnabled()
			log.info kleur.yellow "Connecting to #{url} (secure) ..."
		else
			log.info kleur.yellow "Connecting to #{url} ..."

		@mqtt = mqtt.connect url, options
		@mqtt
			.on "connect", @onConnect
			.on "error",   @onError

	onConnect: =>
		log.info kleur.green "Connected to the broker"

		@mqtt
			.on "packetreceive", @onPacket
			.on "error",         @onError
			.on "reconnect",     @onReconnect
			.on "offline",       @onOffline
			.on "close",         @onClose

		@emit "connect"

	onError: (error) ->
		if error.message?.match /certificate is not yet valid/
			log.error "Host date not valid yet, restarting self ..."
			process.exit 1

		if error.message?.match /EAI_AGAIN/
			log.error "Host DNS failure, restarting self ..."
			process.exit 1

		log.error kleur.red error.message

	onPacket: (packet) =>
		return unless packet
		return unless packet?.topic
		return unless packet?.cmd is "publish"

		forEach @_events, (fn, topic) =>
			payload  = packet.payload.toString()
			expanded = @expandTopic topic
			return unless MQTTPattern.matches expanded, packet.topic

			@emit topic, packet.topic, payload

	onReconnect: ->
		log.warn "Reconnecting to the MQTT broker ..."

	onOffline: ->
		log.warn "Disconnected"

	onClose: =>
		@mqtt
			.removeListener "packetreceive", @onPacket
			.removeListener "error",         @onError
			.removeListener "reconnect",     @onReconnect
			.removeListener "offline",       @onOffline
			.removeListener "close",         @onClose

		@emit "close"

	getWill: ->
		topic:   "devices/#{@clientId}/status"
		payload: "offline"
		retain:  true

	expandTopic: (topic) =>
		topic.replace /{id}/g, @clientId

	createTopic: (topic) ->
		rootTopic = "devices/#{@clientId}"
		topic     = topic.replace rootTopic, ""

		rootTopic
			.concat topic
			.replace /\/{2,}/, ""

	fork: ->
		throw new Error "You must connect to the broker before you can fork the MQTT client" unless @mqtt
		@mqtt

	publish: (topic, message, options = {}) ->
		@mqtt.publish @createTopic(topic), message, options

	subscribe: (topics) ->
		@connect() unless @mqtt

		topics            = [topics] unless isArray topics
		topics            = topics.map @expandTopic
		@subscribedTopics = uniq @subscribedTopics.concat topics

		@mqtt.subscribe topics

module.exports = Client
