_             = require "lodash"
config        = require "config"
{ promisify } = require "util"

pkg            = require "../../package.json"
getIpAddresses = require "../helpers/getIPAddresses"
log            = (require "../lib/Logger") "StateManager"

{ isPlainObject, isEqual, map } = _

class StateManager
	constructor: (@socket, @docker, @groupManager) ->
		@clientId           = config.mqtt.clientId
		@localState         = globalGroups: {}
		@nsState            = {}
		@throttledPublishes = {}

		@throttledSendState    = _.throttle @sendStateToMqtt,    config.state.sendStateThrottleTime
		@throttledSendAppState = _.throttle @sendAppStateToMqtt, config.state.sendAppStateThrottleTime

	publish: (options, cb) =>
		throw new Error ".publish no longer supports callbacks" if cb

		message = options.message
		message = JSON.stringify message unless _.isString message
		topic   = [
			"devices"
			@clientId
			options.topic
		]
			.join "/"
			.replace /\/{2,}/, "/"

		promisify(@socket.publish.bind @socket) topic, message, options.opts

	sendStateToMqtt: =>
		state       = await @generateStateObject()
		stringified = JSON.stringify state
		byteLength  = Buffer.byteLength stringified, "utf8"

		if byteLength > 20000
			log.warn "State exceeds recommended byte length: #{byteLength}/20000 bytes"

		await @publish
			topic:   "state"
			message: state
			opts:    retain: true

		log.info "State published"

	sendAppStateToMqtt: =>
		@publish
			topic:   "nsState/containers"
			message: await promisify(@docker.listContainers.bind @docker)()

	notifyOnlineStatus: =>
		@publish
			topic:   "status"
			message: "online"
			opts:    retain: true

	publishLog: ({ type, message, time }) ->
		@publish
			topic:   "logs"
			message: { type, message, time }
			opts:    retain: true

	sendNsState: (nsState) ->
		return unless isPlainObject nsState

		await Promise.all map nsState, (value, key) =>
			return if isEqual @nsState[key], nsState[key]

			@nsState[key] = nsState[key]
			@publish
				topic:   "nsState/#{key}"
				message: value
				opts:    retain: true

		log.info "Namespaced state published for '#{Object.keys(nsState).join ', '}'"

	generateStateObject: ->
		[images, containers, systemInfo] = await Promise.all [
			promisify(@docker.listImages.bind @docker)()
			@docker.listContainers()
			@docker.getDockerInfo()
		]

		groups     = @groupManager.getGroups()
		systemInfo = Object.assign {},
			systemInfo
			getIpAddresses()
			appVersion: pkg.version

		Object.assign {},
			{ groups }
			{ systemInfo }
			{ images }
			{ containers }
			{ deviceId: @clientId }

module.exports = StateManager
