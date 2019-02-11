RPC                        = require "mqtt-json-rpc"
async                      = require "async"
config                     = require "config"
{ EventEmitter }           = require "events"
{ last, uniqueId, uniqBy } = require "lodash"

class TaskManager extends EventEmitter
	constructor: (mqtt) ->
		super()

		@rpc        = new RPC mqtt
		@registered = []
		@finished   = []
		@queue      = async.queue @handleTask

	handleTask: ({ name, fn, params, taskId, queuedOn }, cb) =>
		baseProperties =
			name:     @getTaskName name
			params:   params
			queuedOn: queuedOn
			taskId:   taskId

		fn ...params
			.then =>
				@finishTask Object.assign {},
					baseProperties
					status: "ok"

				cb()
			.catch (error) =>
				@finishTask Object.assign {},
					baseProperties
					status: "error"
					error:
						message: error.message
						code:    error.code

				cb error

	addTask: ({ name, fn, params }) ->
		@queue.push
			name:     name
			fn:       fn
			params:   params
			taskId:   uniqueId()
			queuedOn: Date.now()
		, (error) =>
			@emit "done",
				name:   @getTaskName name
				params: params

		@emit "task",
			name:     @getTaskName name
			params:   params

	finishTask: ({ name, params, taskId, queuedOn, status, error }) ->
		@finished.shift() while @finished.length > config.queue.maxStoredTasks

		@finished.push Object.assign {},
			finished:   true
			finishedAt: Date.now()
			name:       name
			params:     params
			queuedOn:   queuedOn
			status:     status
			taskId:     taskId
		,
			error: error if error

	getTaskName: (fullTaskName) ->
		last fullTaskName?.split "/"

	getTasks: ->
		extractFromQueuedTask = (source, finished) =>
			finished:   finished
			name:       @getTaskName source.name
			params:     source.params
			taskId:     source.taskId
			queuedOn:   source.queuedOn
			finishedAt: source.finishedAt

		uniqBy ([]
			.concat @queue.workersList().map ({ data }) ->
				extractFromQueuedTask data, false
			.concat @queue._tasks.toArray().map (task) ->
				extractFromQueuedTask task, false
			.concat @finished
		), "taskId"

	register: (name, fn) ->
		@unregister name if @registered.includes name
		@registered.push name

		@rpc.register name, fn

	unregister: (name) ->
		@rpc.unregister name

module.exports = TaskManager
