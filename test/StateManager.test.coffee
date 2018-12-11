assert                     = require "assert"
async                      = require "async"
config                     = require "config"
fs                         = require "fs"
spy                        = require "spy"
{ map, identity, isArray } = require "lodash"

Docker       = require "../src/lib/Docker"
StateManager = require "../src/manager/StateManager"

docker = new Docker

describe ".StateManager", ->
	it "should publish on topic with top level key", (done) ->
		mocket         = {}
		mocket.publish = spy identity
		state          = new StateManager mocket

		state.publishNamespacedState
			je:
				moeder: 1
		, (error) ->
			assert.ifError error
			assert.equal mocket.publish.calls[0].return, "devices/test-device/nsState/je"
			done()

	it "should not publish when sending equal state object", (done) ->
		mocket = publish: spy()
		state  = new StateManager mocket

		async.timesSeries 3, (n, next) ->
			state.publishNamespacedState
				je:
					moeder: "Hetzelfde"
			, next
		, (error) ->
			assert.ifError error
			assert.equal mocket.publish.callCount, 1
			done()

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
			state.publishNamespacedState
				je:
					moeder: i
			, cb
		, ->
			assert.equal mocket.publish.callCount, 1
			done()

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

		async.eachSeries states, (s, next) ->
			setTimeout ->
				state.publishNamespacedState s, next
			, config.state.sendStateThrottleTime
		, (error) ->
			lastState = mocket
				.publish
				.calls[mocket.publish.callCount - 1]
				.return

			assert.ifError error
			assert.equal mocket.publish.callCount, 3
			assert.deepEqual lastState, states[3].topLevelKey
			done()


	it "should callback immediatly when sending empty", (done) ->
		mocket = publish: spy()
		state  = new StateManager mocket

		state.publishNamespacedState null, ->
			assert.equal mocket.publish.called, 0
			done()

	it "should put data in separate topics", (done) ->
		mocket         = {}
		mocket.publish = spy identity

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

			docker.dockerEventStream.once "end", done
			docker.stop()

	describe ".groups", ->
		after ->
			try
				fs.unlinkSync config.groups.path
			catch error
				throw error unless error.code is "ENOENT" and error.path.match config.groups.path

		it "should be able to read groups as an object", ->
			fs.writeFileSync config.groups.path, JSON.stringify
				1: "default"
				2: "hello-world"

			state    = new StateManager
			contents = JSON.parse fs.readFileSync config.groups.path, "utf8"

			assert.ok not isArray contents
			assert.deepStrictEqual state.getGroups(), ["default", "hello-world"]

		it "should be able to read groups as an array", ->
			fs.writeFileSync config.groups.path, JSON.stringify ["default", "hello-world"]

			state    = new StateManager
			contents = JSON.parse fs.readFileSync config.groups.path, "utf8"

			assert.ok isArray contents
			assert.deepStrictEqual state.getGroups(), ["default", "hello-world"]

		it "should send groups as an array from an object", (done) ->
			fs.writeFileSync config.groups.path, JSON.stringify
				1: "default"
				2: "hello-world"

			state    = new StateManager undefined, docker
			contents = JSON.parse fs.readFileSync config.groups.path, "utf8"

			assert.ok not isArray contents
			assert.deepStrictEqual state.getGroups(), ["default", "hello-world"]

			state.generateStateObject (error, { groups }) ->
				return done error if error

				assert.deepStrictEqual groups, ["default", "hello-world"]
				done()

		it "should send groups as an array from an array", (done) ->
			fs.writeFileSync config.groups.path, JSON.stringify ["default", "hello-world"]

			state    = new StateManager undefined, docker
			contents = JSON.parse fs.readFileSync config.groups.path, "utf8"

			assert.ok isArray contents
			assert.deepStrictEqual state.getGroups(), ["default", "hello-world"]

			state.generateStateObject (error, { groups }) ->
				return done error if error

				assert.deepStrictEqual groups, ["default", "hello-world"]
				done()
