RPC               = require "mqtt-json-rpc"
assert            = require "assert"
config            = require "config"
mosca             = require "mosca"
mqtt              = require "mqtt"
{ random, first } = require "lodash"

registerFunction = require "../src/helpers/registerFunction"

TaskManager = require "../src/manager/TaskManager"
thenable    = (delay) -> ->
	new Promise (resolve) ->
		return resolve() unless delay

		setTimeout resolve, delay

resolver = ->
	Promise.resolve()

describe.only ".TaskManager", ->
	port   = random 5000, 10000
	server = null
	client = null

	before (done) ->
		server = new mosca.Server port: port
		client = mqtt.connect port: port, clientId: config.mqtt.clientId

		client.once "connect", -> done()

	after ->
		client.end()
		server.close()

	it "should start with no tasks", ->
		manager = new TaskManager client

		assert.equal manager.getTasks().length, 0

	it "should emit 'added' event when a new task is added", (done) ->
		manager = new TaskManager client

		manager.once "added", ({ name, params }) ->
			assert.deepStrictEqual params, ["a"]
			assert.equal name, "hello-world"
			assert.equal manager.getTasks().length, 1
			done()

		manager.addTask
			fn:     thenable 1000
			name:   "hello-world"
			params: ["a"]

	it "should emit 'done' event when a task is completed", (done) ->
		manager = new TaskManager client

		manager.once "done", ({ name, params }) ->
			tasks = manager.getTasks()
			assert.equal tasks.length, 1

			task = first tasks

			assert.deepStrictEqual params, ["b"]
			assert.equal name, task.name
			assert.ok task.finished
			done()

		manager.addTask
			fn:     thenable()
			name:   "hello-world"
			params: ["b"]

	it "should sort tasks in the order of arrival", ->
		manager     = new TaskManager client
		taskCreator = ->
			name:   "hello-world"
			params: [random Number.MIN_SAFE_INTEGER, Number.MAX_SAFE_INTEGER]
		tasks = [taskCreator(), taskCreator(), taskCreator()]

		tasks.forEach (task) ->
			manager.addTask
				name:   task.name
				params: task.params
				fn:     thenable 1000

		processedTasks = manager
			.getTasks()
			.map ({ name, params }) ->
				{ name, params }

		assert.deepStrictEqual processedTasks, tasks

	it "should add tasks from rpc", (done) ->
		rpc     = new RPC client
		manager = new TaskManager client

		manager.once "added", ({ name, params }) ->
			assert.deepStrictEqual params, [test: true]
			assert.equal name, "test"
			done()

		registerFunction
			fn:   resolver
			name: "test"
			rpc:  manager

		rpc.notify "actions/#{config.mqtt.clientId}/test", test: true
