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
		fn ...params
			.then =>
				@finishTask
					name:     @getTaskName name
					params:   params
					taskId:   taskId
					queuedOn: queuedOn

				cb()
			.catch (error) ->
				cb error

	addTask: ({ name, fn, params }) ->
		@queue.push
			name:     name
			fn:       fn
			params:   params
			taskId:   uniqueId()
			queuedOn: Date.now()
		, (error) =>
			return @emit "error", error if error

			@emit "done",
				name:   @getTaskName name
				params: params

		@emit "task",
			name:     @getTaskName name
			params:   params

	finishTask: ({ name, params, taskId, queuedOn }) ->
		@finished.shift() if @finished.length > config.queue.maxStoredTasks

		@finished.push
			finished:   true
			finishedAt: Date.now()
			name:       name
			params:     params
			queuedOn:   queuedOn
			taskId:     taskId

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
