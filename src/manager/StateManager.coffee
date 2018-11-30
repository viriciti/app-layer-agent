_     = require "lodash"
async = require "async"
debug = (require "debug") "app:StateManager"
fs    = require "fs"
path  = require "path"

pkg            = require "../../package.json"
getIpAddresses = require "../helpers/getIPAddresses"
log            = (require "../lib/Logger") "StateManager"

module.exports = (config, getSocket, docker) ->
	clientId   = config.host

	localState =
		globalGroups:    {}

	nsState                  = {}
	throttledCustomPublishes = {}

	customPublish = (opts, cb) ->
		socket = getSocket()

		unless socket
			log.warn "Could not custom publish on topic `#{opts.topic}`"
			return cb?()

		debug "Sending data to #{opts.topic}"

		socket.publish opts.topic, opts.message, opts.opts, cb

	_sendStateToMqtt = (cb) ->
		log.info "Sending state.."
		_generateStateObject (error, state) ->
			return cb error if error

			debug "State is", JSON.stringify _.omit state, ["images", "containers"]

			stateStr   = JSON.stringify state
			byteLength = Buffer.byteLength stateStr, 'utf8'
			log.warn "State exceeds recommended byte length: #{byteLength}/20000 bytes" if byteLength > 20000 # .02MB spam per 2 sec = 864MB in 24 hrs

			customPublish
				topic: "devices/#{clientId}/state"
				message: stateStr
				opts:
					retain: true
					qos: 1
			, (error) ->
				if error
					log.error "Error in custom state publish: #{error.message}"
				else
					log.info "State published!"

				cb? error

	throttledSendState = _.throttle (-> _sendStateToMqtt()), config.sendStateThrottleTime

	notifyOnlineStatus = () ->
		log.info "Setting status: online"
		customPublish
			topic: "devices/#{clientId}/status"
			message: "online"
			opts:
				retain: true
				qos:    1

	publishLog = ({ type, message, time }) ->
		data = JSON.stringify { type, message, time }
		debug "Sending: #{data}"
		customPublish
			topic: "devices/#{clientId}/logs"
			message: data
			opts:
				retain: true
				qos:    0
		, (error) ->
			return log.error "Error in customPublish: #{error.message}" if error
			debug "Sent: #{data}"

	# One of the ideas behind this approach is that we can give it any arbitrary object with some top level keys and it
	# will automagically put it into topics namespaced by those top level keys
	# NOTE! This function will side effect on the nsState object! : )
	publishNamespacedState = (newState, cb) ->
		return cb?() if _.isEmpty newState

		async.eachOf newState, (val, key, cb) ->
			currentVal = nsState[key]
			return cb() if _.isEqual currentVal, val

			nsState[key] = val
			stringified  = JSON.stringify val
			byteLength   = Buffer.byteLength stringified, 'utf8'

			log.warn "#{key}: Buffer.byteLength = #{byteLength}!" if byteLength > 1024

			throttledCustomPublishes[key] or= _.throttle customPublish, config.sendStateThrottleTime

			throttledCustomPublishes[key]
				topic: "devices/#{clientId}/nsState/#{key}"
				message: stringified
				opts:
					retain: true
					qos:    0
			, (error) ->
				log.error "Error in customPublish: #{error.message}" if error

			cb()
		, -> cb?()

	throttledSendAppState = _.throttle ->
		docker.listContainers (error, containers) ->
			return log.error log.error if error

			customPublish
				topic:   "devices/#{clientId}/nsState/containers"
				message: JSON.stringify containers
				opts:
					retain: false
			, (error) ->
				return log.error "Error publishing app state: #{error.message}" if error

				debug "App state published"
	, config.sendAppStateThrottleTime

	sendNsState = ->
		async.eachOf nsState, (val, key, cb) ->
			customPublish
				topic:   "devices/#{clientId}/nsState/#{key}"
				message: JSON.stringify val
				opts:    retain: true
			, cb
		, (error) ->
			return log.error "Error publishing namespaced state: #{error.message}" if error

			log.info "Namespaced state published for #{_(nsState).keys().join ", "}"

	getDeviceId = -> clientId

	getGroups = ->
		debug "Groups file: #{config.groups.path}"

		unless fs.existsSync config.groups.path
			setDefaultGroups()
			log.info "Groups configured with default configuration"

		try
			groups = JSON.parse (fs.readFileSync config.groups.path).toString()
		catch error
			log.error "Error while parsing groups, setting default configuration ..."
			setDefaultGroups()

		groups = _.extend groups, 1: "default"

		debug "Groups: #{JSON.stringify groups}"

		groups

	setDefaultGroups = ->
		setGroups 1: "default"

	setGroups = (groups) ->
		groups = "#{JSON.stringify groups}\n"
		log.info "Setting groups file: #{groups}"
		fs.writeFileSync config.groups.path, groups

		throttledSendState()

	setGlobalGroups = (globalGroups) ->
		debug "Set global groups to: #{JSON.stringify globalGroups}"
		localState = _.extend {}, localState, { globalGroups }

	# The global groups come out of mqtt. These are all groups available to all devices
	getGlobalGroups = ->
		localState.globalGroups

	updateFinishedQueueList = (finishedTask) ->
		oldList = nsState["finishedQueueList"] or []
		newList = [ finishedTask ].concat oldList.slice 0, 9 # only keep 10

		publishNamespacedState finishedQueueList: newList

	_generateStateObject = (cb) ->
		debug "Generating state object"

		async.parallel
			images:     docker.listImages
			containers: docker.listContainers
			systemInfo: docker.getDockerInfo
		, (error, { images, containers, systemInfo }) ->
			if error
				log.error "Error generating state object: #{error.message}"
				return cb error

			groups     = _(getGroups()).values()
			systemInfo = _.extend {},
				systemInfo
				getIpAddresses()
				dmVersion: pkg.version

			state = _.extend {},
				{ groups }
				{ systemInfo }
				{ images }
				{ containers }
				{ deviceId: clientId }

			cb null, state

	return {
		getDeviceId
		getGlobalGroups
		getGroups
		notifyOnlineStatus
		publishLog
		publishNamespacedState
		updateFinishedQueueList
		setGlobalGroups
		setGroups
		throttledSendAppState
		throttledSendState
		sendNsState
	}
