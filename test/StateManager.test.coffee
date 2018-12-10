assert = require "assert"
async  = require "async"
config = require "config"
spy    = require "spy"
{ map } = require "lodash"

Docker       = require "../src/lib/Docker"
StateManager = require "../src/manager/StateManager"

docker = new Docker

describe ".StateManager", ->
	it "should publish on topic with top level key", ->
		mocket         = {}
		mocket.publish = (topic) ->
			assert.equal topic, "devices/test-device/nsState/je"

		state = new StateManager mocket

		state.publishNamespacedState { je: { moeder: 1 } }

	it "should not publish when sending equal state object", (done) ->
		mocket = publish: spy()
		state  = new StateManager mocket

		async.timesSeries 3, (n, cb) ->

			setTimeout ->
				state.publishNamespacedState { je: { moeder: "Hetzelfde" } }, cb
			, config.sendStateThrottleTime * n
		, ->
			setTimeout ->
				assert.equal mocket.publish.callCount, 1

				done()
			, config.sendStateThrottleTime * 2

	it "should throttle properly", (done) ->
		mocket         = {}
		mocket.publish = spy (topic, message) ->
			message = JSON.parse message

			if @publish.callCount is 0
				assert.deepEqual message, moeder: 0
			else if @publish.callCount is 1
				assert.deepEqual message, moeder: 2

		state = new StateManager mocket

		async.times 3, (i, cb) ->
			state.publishNamespacedState { je: { moeder: i } }, cb
		, ->
			setTimeout done, config.sendStateThrottleTime * 2

	it "should publish when nested values are changed, but not when equal", (done) ->
		mocket         = {}
		mocket.publish = spy (topic, message) ->
			JSON.parse message


		state  = new StateManager mocket
		states =
			[
				{ topLevelKey: { moeder: 1, bla: [ { yolo: "dingen" } ] } }
				{ topLevelKey: { moeder: 1, bla: [ { yolo: "dingen" }, { yolo: "meer dingen", arr: [ { key: "val1" } ] } ] } }
				{ topLevelKey: { moeder: 1, bla: [ { yolo: "dingen" }, { yolo: "meer dingen", arr: [ { key: "val2" } ] } ] } }
				{ topLevelKey: { moeder: 1, bla: [ { yolo: "dingen" }, { yolo: "meer dingen", arr: [ { key: "val2" } ] } ] } }
				{ topLevelKey: { moeder: 1, bla: [ { yolo: "dingen" }, { yolo: "meer dingen", arr: [ { key: "val2" } ] } ] } }
				{ topLevelKey: { moeder: 1, bla: [ { yolo: "dingen" }, { yolo: "meer dingen", arr: [ { key: "val2" } ] } ] } }
			]

		async.eachSeries states, (s, cb) ->
			setTimeout ->
				state.publishNamespacedState s, cb
			, config.sendStateThrottleTime + 10
		, ->
			setTimeout ->
				lastState = mocket
					.publish
					.calls[mocket.publish.callCount - 1]
					.return

				assert.equal mocket.publish.callCount, 3
				assert.deepEqual lastState, states[3].topLevelKey
				done()
			, config.sendStateThrottleTime + 10


	it "should callback immediatly when sending empty", (done) ->
		mocket = publish: spy()
		state  = new StateManager mocket

		state.publishNamespacedState null, ->
			setTimeout ->
				assert.ifError mocket.publish.called
				done()
			, 50

	it "should put data in separate topics", (done) ->
		mocket         = {}
		mocket.publish = spy (topic) ->
			topic

		state = new StateManager mocket

		state.publishNamespacedState {
			one:   { dingen: "dingen1" }
			two:   { dingen: "dingen2" }
			three: { dingen: "dingen3" }
			four:  { dingen: "dingen4" }
			five:  { dingen: "dingen5" }
		}, ->
			assert.deepEqual map(mocket.publish.calls, "return"), [
				"devices/test-device/nsState/one"
				"devices/test-device/nsState/two"
				"devices/test-device/nsState/three"
				"devices/test-device/nsState/four"
				"devices/test-device/nsState/five"
			]

			docker
				.dockerEventStream
				.once "end", ->
					done()

			docker.stop()
