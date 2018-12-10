async  = require "async"
config = require "config"
assert = require "assert"

Docker       = require "../src/lib/Docker"
StateManager = require "../src/manager/StateManager"

docker = new Docker

describe ".StateManager", ->
	it "should publish on topic with top level key", ->
		mocket = {}
		mocket.customPublish = (data) ->
			assert.equal data.topic, "devices/test-device/nsState/je", "It publishes on topic with top level key"

		getSocket = -> mocket
		state     = new StateManager config, getSocket, docker

		state.publishNamespacedState { je: { moeder: 1 } }

	it "should not publish when sending equal state object", (done) ->
		mocket  = {}
		counter = 0
		mocket.customPublish = (data) ->
			counter += 1

		getSocket = -> mocket
		state     = new StateManager config, getSocket, docker

		async.eachSeries [1..3], (i, cb) ->
			setTimeout ->
				state.publishNamespacedState { je: { moeder: "Hetzelfde" } }, cb
			, config.sendStateThrottleTime * 2
		, ->
			setTimeout ->
				assert.equal counter, 1, "Should not publish when sending equal state object"
				done()
			, config.sendStateThrottleTime * 2

	it "should throttle properly", (done) ->
		mocket  = {}
		counter = 0

		mocket.customPublish = (data) ->
			++counter
			msg = JSON.parse data.message
			if counter is 1
				assert.deepEqual msg, { moeder: 1 }, "Should send the state immediately even though throttled"

			if counter is 2
				assert.deepEqual msg, { moeder: 3 }, "Should have skipped the second send and go straight to the latest state"
				assert.equal counter, 2, "customPublish should have been called 2 times"

		getSocket = -> mocket

		state = new StateManager config, getSocket, docker

		async.eachSeries [1..3], (i, cb) ->
			state.publishNamespacedState { je: { moeder: i } }, cb
		, ->
			setTimeout done, config.sendStateThrottleTime * 2

	it "should publish when nested values are changed, but not when equal", (done) ->
		mocket  = {}
		counter = 0
		lastState = null
		mocket.customPublish = (data) ->
			lastState = JSON.parse data.message
			counter++

		getSocket = -> mocket

		state = new StateManager config, getSocket, docker

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
				assert.equal counter, 3, "Should publish with changing deeply nested values, but not when equal"
				assert.deepEqual lastState, states[3].topLevelKey, "Should have the last state"
				done()
			, config.sendStateThrottleTime + 10


	it "should callback immediatly when sending empty", (done) ->
		mocket  = {}
		counter = 0
		mocket.customPublish = (data) ->
			counter++

		getSocket = -> mocket

		state = new StateManager config, getSocket, docker

		state.publishNamespacedState null, ->
			setTimeout ->
				assert.equal counter, 0, "Should cb immediately when sending empty"
				done()
			, 50

	it "should put data in separate topics", (done) ->
		mocket  = {}
		topics  = []
		mocket.customPublish = (data) ->
			topics.push data.topic

		getSocket = -> mocket
		state     = new StateManager config, getSocket, docker

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

			assert.deepEqual topics, expectedTopics, "It should put data in seperate topics"
			docker
				.dockerEventStream
				.once "end", ->
					done()
			docker.stop()
