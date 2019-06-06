RPC                                    = require "mqtt-json-rpc"
assert                                 = require "assert"
config                                 = require "config"
mosca                                  = require "mosca"
mqtt                                   = require "mqtt"
{ random, first, isPlainObject, noop } = require "lodash"

registerFunction = require "../src/helpers/registerFunction"

TaskManager = require "../src/manager/TaskManager"
thenable    = (delay) -> ->
	new Promise (resolve) ->
		return resolve() unless delay

		setTimeout resolve, delay

resolver = ->
	Promise.resolve()

describe ".TaskManager", ->
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

	it "should emit 'task' event when a new task is added", (done) ->
		manager = new TaskManager client

		manager.once "task", ({ name, params }) ->
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

		noop

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

		manager.once "task", ({ name, params }) ->
			assert.deepStrictEqual params, [test: true]
			assert.equal name, "test"
			done()

		registerFunction
			fn:          resolver
			name:        "test"
			taskManager: manager

		rpc.notify "actions/#{config.mqtt.clientId}/test", test: true

	it "should add queued time when adding a new task", ->
		manager = new TaskManager client

		manager.addTask
			fn:     thenable 1000
			name:   "hello-world"
			params: ["a"]

		task = first manager.getTasks()
		now  = Date.now()

		assert.ok task.queuedOn
		assert.ok task.queuedOn < now + 1000
		assert.ok task.queuedOn > now - 1000

	it "should add finished time when a task is done", (done) ->
		manager = new TaskManager client

		manager.once "done", ->
			task = first manager.getTasks()
			now  = Date.now()

			assert.notEqual task.queuedOn, task.finishedAt
			assert.ok task.finishedAt < now + 1000
			assert.ok task.finishedAt > now - 1000
			done()

		manager.addTask
			fn:     thenable 100
			name:   "hello-world"
			params: ["a"]
		noop

	it "should add an error status if a task fails", (done) ->
		manager    = new TaskManager client
		error      = new Error "Well, this failed"
		error.code = 15

		manager.once "done", ->
			task = first manager.getTasks()

			assert.ok isPlainObject task.error
			assert.equal task.status,        "error"
			assert.equal task.error.message, "Well, this failed"
			assert.equal task.error.code,    15
			done()

		manager.addTask
			fn:     -> Promise.reject error
			name:   "hello-world"
			params: ["a"]
		noop
