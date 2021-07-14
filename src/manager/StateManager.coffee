{ throttle, isString, isEqual, isPlainObject, map, defaultTo } = require "lodash"
config                                                         = require "config"
debug                                                          = (require "debug") "app:manager:state-manager"

pkg            = require "../../package.json"
getIPAddresses = require "../helpers/getIPAddresses"
getOSVersion   = require "../datahub/getOSVersion"
log            = (require "../lib/Logger") "StateManager"

class StateManager
	constructor: (@socket, @docker, @groupManager) ->
		@clientId           = config.mqtt.clientId
		@localState         = globalGroups: {}
		@nsState            = {}
		@throttledPublishes = {}

		@throttledSendState    = throttle @sendStateToMqtt,    config.state.sendStateThrottleTime
		@throttledSendAppState = throttle @sendAppStateToMqtt, config.state.sendAppStateThrottleTime

	publish: (options) =>
		message = options.message
		message = JSON.stringify message unless isString message
		topic   = [
			"devices"
			@clientId
			options.topic
		]
			.join "/"
			.replace /\/{2,}/, "/"

		@socket.publish topic, message, options.opts

	heartbeat: =>
		now = new Date

		if @latestHeartbeat
			diff = +now - +@latestHeartbeat
			if diff < config.heartbeatMinInterval
				debug "Not sending heartbeat: interval %d is smaller then minimum %d", diff, config.heartbeatMinInterval
				return

		debug "Sending heartbeat on %s", now
		@publish
			topic:   "heartbeat"
			message: now
			opts:    retain: true

		@latestHeartbeat = now

	sendStateToMqtt: =>
		state       = await @generateStateObject()
		stringified = JSON.stringify state
		byteLength  = Buffer.byteLength stringified, "utf8"

		if byteLength > 20000
			log.warn "State exceeds recommended byte length: #{byteLength}/20000 bytes"

		@heartbeat()

		await @publish
			topic:   "state"
			message: state
			opts:    retain: true

		log.info "State published"

	sendAppStateToMqtt: =>
		@heartbeat()

		@publish
			topic:   "nsState/containers"
			message: await @docker.listContainers()

	sendSystemStateToMqtt: =>
		@heartbeat()

		systemInfo = await @docker.getDockerInfo()
		addresses  = getIPAddresses()
		appVersion = pkg.version

		@publish
			topic: "nsState/systemInfo"
			message: JSON.stringify Object.assign {},
				systemInfo
				addresses
				appVersion: appVersion

	notifyOnlineStatus: =>
		@heartbeat()

		@publish
			topic:   "status"
			message: "online"
			opts:    retain: true

	publishLog: ({ type, message, time }) ->
		@heartbeat()

		@publish
			topic:   "logs"
			message: { type, message, time }
			opts:    retain: true

	sendNsState: (nsState) ->
		return unless isPlainObject nsState

		await Promise.all map nsState, (value, key) =>
			return if isEqual @nsState[key], nsState[key]

			@nsState[key] = nsState[key]

			@heartbeat()

			@publish
				topic:   "nsState/#{key}"
				message: value
				opts:    retain: true

		log.info "Namespaced state published for '#{Object.keys(nsState).join ', '}'"

	generateStateObject: ->
		[images, containers, systemInfo] = await Promise.all [
			@docker.listImages()
			@docker.listContainers()
			@docker.getDockerInfo()
		]

		systemInfo = Object.assign {},
			systemInfo
			getIPAddresses()
			appVersion: pkg.version
			osVersion:  defaultTo getOSVersion(), "n/a"

		Object.assign {},
			{ systemInfo }
			{ images }
			{ containers }
			{ deviceId: @clientId }

module.exports = StateManager
