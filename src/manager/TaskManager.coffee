RPC                = require "mqtt-json-rpc"
Queue              = require "p-queue"
{ EventEmitter }   = require "events"
{ last, uniqueId } = require "lodash"

class TaskManager extends EventEmitter
	constructor: (mqtt) ->
		super()

		@rpc        = new RPC mqtt
		@registered = []
		@finished   = []
		@tasks      = []
		@queue      = new Queue()

	addTask: ({ name, fn, params }) ->
		task =
			name:     @getTaskName name
			params:   params
			queuedOn: Date.now()
			taskId:   uniqueId()

		@tasks.push task

		try
			@emit "task",
				name:   @getTaskName name
				params: params

			await @queue.add -> fn ...params

			@finishTask Object.assign {},
				task
				status: "ok"
		catch error
			@finishTask Object.assign {},
				task
				status: "error"
				error:
					message: error.message
					code:    error.code
		finally
			@emit "done",
				name:   @getTaskName name
				params: params

	finishTask: ({ name, params, taskId, queuedOn, status, error }) ->
		predicate    = (task) -> taskId is task.taskId
		finishedTask = @tasks.find predicate

		throw new Error "Task #{taskId} not found" unless finishedTask

		taskIndex    = @tasks.findIndex predicate
		finishedTask = Object.assign {},
			finishedTask
			finished:   true
			finishedAt: Date.now()
			status:     status
		,
			error: error if error

		@tasks[taskIndex] = finishedTask
		@tasks[taskIndex]

	getTaskName: (name) ->
		last name?.split "/"

	getTasks: ->
		@tasks

	register: (name, fn) ->
		@unregister name if @registered.includes name
		@registered.push name

		@rpc.register name, fn

	unregister: (name) ->
		@rpc.unregister name

module.exports = TaskManager
