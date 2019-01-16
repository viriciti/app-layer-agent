assert            = require "assert"
spy               = require "spy"
{ map, identity } = require "lodash"

StateManager = require "../src/manager/StateManager"

describe ".StateManager", ->
	it "should publish on topic with top level key", ->
		mocket         = {}
		mocket.publish = spy identity
		state          = new StateManager mocket

		state.sendNsState
			state:
				ok: false

		assert.equal mocket.publish.calls[0].return, "devices/test-device/nsState/state"

	it "should not publish when sending equal state object", ->
		mocket = publish: spy()
		state  = new StateManager mocket

		state.sendNsState same: value: true
		state.sendNsState same: value: true
		state.sendNsState same: value: true

		assert.equal mocket.publish.callCount, 1

	it "should publish when nested values are changed, but not when equal", ->
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

		Promise.all states.map (object) ->
			state.sendNsState object

		lastState = mocket
			.publish
			.calls[mocket.publish.callCount - 1]
			.return

		assert.equal mocket.publish.callCount, 3
		assert.deepEqual lastState, states[3].topLevelKey

	it "should callback immediatly when sending empty", ->
		mocket = publish: spy()
		state  = new StateManager mocket

		state.sendNsState null
		assert.equal mocket.publish.called, 0

	it "should put data in separate topics", ->
		mocket         = {}
		mocket.publish = spy identity

		state = new StateManager mocket

		state.sendNsState
			one:   { dingen: "dingen1" }
			two:   { dingen: "dingen2" }
			three: { dingen: "dingen3" }
			four:  { dingen: "dingen4" }
			five:  { dingen: "dingen5" }

		assert.deepEqual map(mocket.publish.calls, "return"), [
			"devices/test-device/nsState/one"
			"devices/test-device/nsState/two"
			"devices/test-device/nsState/three"
			"devices/test-device/nsState/four"
			"devices/test-device/nsState/five"
		]
