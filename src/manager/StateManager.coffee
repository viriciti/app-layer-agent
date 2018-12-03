_      = require "lodash"
async  = require "async"
config = require "config"
debug  = (require "debug") "app:StateManager"
fs     = require "fs"

pkg            = require "../../package.json"
getIpAddresses = require "../helpers/getIPAddresses"
log            = (require "../lib/Logger") "StateManager"

class StateManager
	constructor: (@socket, @docker) ->
		@clientId           = config.mqtt.clientId
		@localState         = globalGroups: {}
		@nsState            = {}
		@throttledPublishes = {}

		@throttledSendState    = _.throttle @sendStateToMqtt,    config.state.sendStateThrottleTime
		@throttledSendAppState = _.throttle @sendAppStateToMqtt, config.state.sendAppStateThrottleTime

	publish: (options, cb) =>
		topic   = "devices/#{@clientId}/#{options.topic}"
		message = options.message
		message = JSON.stringify message unless _.isString message

		debug "Sending data to #{topic}"
		@socket.publish topic, message, options.opts, cb

	sendStateToMqtt: (cb) =>
		@generateStateObject (error, state) =>
			return cb? error if error

			debug "State is", JSON.stringify _.omit state, ["images", "containers"]

			stateStr   = JSON.stringify state
			byteLength = Buffer.byteLength stateStr, "utf8"

			# .02MB spam per 2 sec = 864MB in 24 hrs
			if byteLength > 20000
				log.warn "State exceeds recommended byte length: #{byteLength}/20000 bytes"

			@publish
				topic:   "state"
				message: state
				opts:
					retain: true
					qos: 1
			, (error) ->
				if error
					log.error "Error while publishing state: #{error.message}"
				else
					log.info "State published!"

				cb? error

	sendAppStateToMqtt: (cb) =>
		@docker.listContainers (error, containers) =>
			return cb? error if error

			@publish
				topic:   "nsState/containers"
				message: containers
				opts:
					retain: false
			, (error) ->
				return cb? error if error

				debug "App state published"
				cb?()

	notifyOnlineStatus: =>
		log.info "Setting status: online"

		@publish
			topic:   "status"
			message: "online"
			opts:
				retain: true

	publishLog: ({ type, message, time }) ->
		@publish
			topic: "logs"
			message: { type, message, time }
			opts:
				retain: true
				qos:    0
		, (error) ->
			return log.error "Error while publishing log: #{error.message}" if error

	publishNamespacedState: (newState, cb) ->
		return cb?() if _.isEmpty newState

		async.eachOf newState, (val, key, next) =>
			currentVal = @nsState[key]
			return next() if _.isEqual currentVal, val

			@nsState[key] = val
			stringified  = JSON.stringify val
			byteLength   = Buffer.byteLength stringified, 'utf8'

			log.warn "#{key}: Buffer.byteLength = #{byteLength}" if byteLength > 1024

			@throttledPublishes[key] or= _.throttle @publish, config.sendStateThrottleTime
			@throttledPublishes[key]
				topic:   "nsState/#{key}"
				message: stringified
				opts:
					retain: true
					qos:    0
			, (error) ->
				log.error "Error in customPublish: #{error.message}" if error

			next()
		, cb

	sendNsState: (cb) ->
		async.eachOf @nsState, (val, key, next) =>
			@publish
				topic:   "nsState/#{key}"
				message: val
				opts:    retain: true
			, next
		, (error) =>
			if error
				log.error "Error publishing namespaced state: #{error.message}"
				return cb? error

			log.info "Namespaced state published for #{Object.keys(@nsState).join ", "}"
			cb?()

	getGroups: ->
		unless fs.existsSync config.groups.path
			@setDefaultGroups()
			log.info "Groups configured with default configuration"

		try
			groups = JSON.parse (fs.readFileSync config.groups.path).toString()
		catch
			log.error "Error while parsing groups, setting default configuration ..."
			@setDefaultGroups()

		groups = Object.assign {}, groups, 1: "default"
		debug "Groups: #{Object.values(groups).join ', '} (from #{config.groups.path})"
		groups

	setGroups: (groups) ->
		log.info "Setting groups to #{Object.values(groups).join ', '}"

		fs.writeFileSync config.groups.path, JSON.stringify groups
		@throttledSendState()

	setDefaultGroups: ->
		@setGroups 1: "default"

	setGlobalGroups: (globalGroups) ->
		debug "Global groups: #{Object.values(globalGroups).join ", "}"
		Object.assign @localState, { globalGroups }

	getGlobalGroups: ->
		@localState.globalGroups

	updateFinishedQueueList: (finishedTask) ->
		oldList = @nsState["finishedQueueList"] or []
		newList = [finishedTask].concat oldList.slice 0, 9 # only keep 10

		@publishNamespacedState finishedQueueList: newList

	generateStateObject: (cb) ->
		async.parallel
			images:     @docker.listImages
			containers: @docker.listContainers
			systemInfo: @docker.getDockerInfo
		, (error, { images, containers, systemInfo } = {}) =>
			if error
				log.error "Error generating state object: #{error.message}"
				return cb error

			groups     = Object.values @getGroups()
			systemInfo = Object.assign {},
				systemInfo
				getIpAddresses()
				appVersion: pkg.version

			state = Object.assign {},
				{ groups }
				{ systemInfo }
				{ images }
				{ containers }
				{ deviceId: @clientId }

			cb null, state

module.exports = StateManager
