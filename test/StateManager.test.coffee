async = require "async"
test  = require "tape"

config =
	host: "test-device"
	docker:
		socketPath: "/var/run/docker.sock"
		maxRetries: 5
		registry_auth:
			required: false

	groups:
		path: "/home/<username>/groups"

	development: true

	sendStateThrottleTime: 50

Docker = require "../src/lib/Docker"
docker = new Docker   config.docker

test "Namespaced state sending 1", (t) ->
	StateManager = require '../src/manager/StateManager'

	mocket = {}
	mocket.customPublish = (data) ->
		t.equal data.topic, "devices/test-device/nsState/je", "It publishes on topic with top level key"
		t.end()

	getSocket = -> mocket

	state  = StateManager config, getSocket, docker

	state.publishNamespacedState { je: { moeder: 1 } }

test "Namespaced state sending 2", (t) ->
	StateManager = require '../src/manager/StateManager'

	mocket  = {}
	counter = 0
	mocket.customPublish = (data) ->
		counter++

	getSocket = -> mocket

	state  = StateManager config, getSocket, docker

	async.eachSeries [1..3], (i, cb) ->
		setTimeout ->
			state.publishNamespacedState { je: { moeder: "Hetzelfde" } }, cb
		, config.sendStateThrottleTime * 2
	, ->
		setTimeout ->
			t.equal counter, 1, "Should not publish when sending equal state object"
		, config.sendStateThrottleTime * 2
		t.end()

test "Namespaced state sending 3 (Basically we're testing underscore.throttle here... Future proofing)", (t) ->
	StateManager = require '../src/manager/StateManager'

	mocket  = {}
	counter = 0

	mocket.customPublish = (data) ->
		++counter
		msg = JSON.parse data.message
		if counter is 1
			t.deepEqual msg, { moeder: 1 }, "Should send the state immediately even though throttled"

		if counter is 2
			t.deepEqual msg, { moeder: 3 }, "Should have skipped the second send and go straight to the latest state"

			t.equal counter, 2, "customPublish should have been called 2 times"

	getSocket = -> mocket

	state  = StateManager config, getSocket, docker

	async.eachSeries [1..3], (i, cb) ->
		state.publishNamespacedState { je: { moeder: i } }, cb
	, ->
		setTimeout t.end, config.sendStateThrottleTime * 2

test "Namespaced state sending 4", (t) ->
	StateManager = require '../src/manager/StateManager'

	mocket  = {}
	counter = 0
	lastState = null
	mocket.customPublish = (data) ->
		lastState = JSON.parse data.message
		counter++

	getSocket = -> mocket

	state  = StateManager config, getSocket, docker

	states =
		[
			{ topLevelKey: { moeder: 1, bla: [ { yolo: "dingen"} ] } }
			{ topLevelKey: { moeder: 1, bla: [ { yolo: "dingen"}, { yolo: "meer dingen", arr: [ { key: "val1" } ] } ] } }
			{ topLevelKey: { moeder: 1, bla: [ { yolo: "dingen"}, { yolo: "meer dingen", arr: [ { key: "val2" } ] } ] } }
			{ topLevelKey: { moeder: 1, bla: [ { yolo: "dingen"}, { yolo: "meer dingen", arr: [ { key: "val2" } ] } ] } } # Same : )
			{ topLevelKey: { moeder: 1, bla: [ { yolo: "dingen"}, { yolo: "meer dingen", arr: [ { key: "val2" } ] } ] } } # Same : )
			{ topLevelKey: { moeder: 1, bla: [ { yolo: "dingen"}, { yolo: "meer dingen", arr: [ { key: "val2" } ] } ] } } # Same : )
		]

	async.eachSeries states, (s, cb) ->
		setTimeout ->
			state.publishNamespacedState s, cb
		, config.sendStateThrottleTime + 10
	, ->
		setTimeout ->
			t.equal counter, 3, "Should publish with changing deeply nested values, but not when equal"
			t.deepEqual lastState, states[3].topLevelKey, "Should have the last state"
			t.end()
		, config.sendStateThrottleTime + 10


test "Namespaced state sending 5", (t) ->
	StateManager = require '../src/manager/StateManager'

	mocket  = {}
	counter = 0
	mocket.customPublish = (data) ->
		counter++

	getSocket = -> mocket

	state  = StateManager config, getSocket, docker

	state.publishNamespacedState null, ->
		setTimeout ->
			t.equal counter, 0, "Should cb immediately when sending empty"
			t.end()
		, 50


test "Namespaced state sending 6", (t) ->
	StateManager = require '../src/manager/StateManager'

	mocket  = {}
	topics  = []
	mocket.customPublish = (data) ->
		topics.push data.topic

	getSocket = -> mocket

	state  = StateManager config, getSocket, docker

	state.publishNamespacedState {
		one:   { dingen: "dingen1" }
		two:   { dingen: "dingen2" }
		three: { dingen: "dingen3" }
		four:  { dingen: "dingen4" }
		five:  { dingen: "dingen5" }
	}, ->
		expectedTopics = [
			"devices/test-device/nsState/one"
			"devices/test-device/nsState/two"
			"devices/test-device/nsState/three"
			"devices/test-device/nsState/four"
			"devices/test-device/nsState/five"
		]

		t.deepEqual topics, expectedTopics, "It should put data in seperate topics"
		docker.dockerEventStream.once "end", ->
			t.end()
		docker.stop()
