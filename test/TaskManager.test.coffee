assert     = require "assert"
mosca      = require "mosca"
mqtt       = require "mqtt"
{ random } = require "lodash"


TaskManager = require "../src/manager/TaskManager"
thenable    = (delay) -> ->
	new Promise (resolve) ->
		return resolve() unless delay

		setTimeout resolve, delay

describe ".TaskManager", ->
	port   = random 5000, 10000
	server = null
	client = null

	before (done) ->
		server = new mosca.Server port: port
		client = mqtt.connect port: port

		client.once "connect", -> done()

	after ->
		client.end()
		server.close()

	it "should start with no remaining tasks", ->
		manager = new TaskManager client

		assert.equal manager.getRemainingTasks().length, 0

	it "should emit 'added' event when a new task is added", (done) ->
		manager = new TaskManager client

		manager.once "added", ({ name, params, remaining }) ->
			assert.deepStrictEqual params, ["a"]
			assert.equal name, "hello-world"
			assert.equal remaining.length, 1
			done()

		manager.addTask
			fn:     thenable 1000
			name:   "hello-world"
			params: ["a"]

	it "should emit 'done' event when a task is completed", (done) ->
		manager = new TaskManager client

		manager.once "done", ({ name, params }) ->
			assert.deepStrictEqual params, ["b"]
			assert.equal name, "hello-world"
			assert.equal manager.getRemainingTasks().length, 0
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

		assert.deepStrictEqual manager.getRemainingTasks(), tasks
