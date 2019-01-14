RPC                        = require "mqtt-json-rpc"
async                      = require "async"
config                     = require "config"
{ EventEmitter }           = require "events"
{ last, uniqueId, uniqBy } = require "lodash"

class TaskManager extends EventEmitter
	constructor: (mqtt) ->
		super mqtt

		@rpc        = new RPC mqtt
		@registered = []
		@finished   = []
		@queue      = async.queue @handleTask

	handleTask: ({ name, fn, params, taskId }, cb) =>
		fn ...params
			.then =>
				cb()

				@finishTask
					name:   @getTaskName name
					params: params
					taskId: taskId

				@emit "done",
					name:     @getTaskName name
					params:   params
			.catch (error) =>
				@emit "error", error
				cb error

	addTask: ({ name, fn, params }) ->
		@queue.push
			name:   name
			fn:     fn
			params: params
			taskId: uniqueId()

		@emit "added",
			name:     @getTaskName name
			params:   params

	finishTask: ({ name, params, taskId }) ->
		@finished.shift() if @finished.length > config.queue.maxStoredTasks

		@finished.push
			finished: true
			name:     name
			params:   params
			taskId:   taskId

	getTaskName: (fullTaskName) ->
		last fullTaskName?.split "/"

	getTasks: ->
		uniqBy ([]
			.concat @queue.workersList().map ({ data }) =>
				finished: false
				name:     @getTaskName data.name
				params:   data.params
				taskId:   data.taskId
			.concat @queue._tasks.toArray().map ({ name, params, taskId }) =>
				finished: false
				name:     @getTaskName name
				params:   params
				taskId:   taskId
			.concat @finished
		), "taskId"

	register: (name, fn) ->
		@unregister name if @registered.includes name
		@registered.push name

		@rpc.register name, fn

	unregister: (name) ->
		@rpc.unregister name

module.exports = TaskManager
