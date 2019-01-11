async            = require "async"
RPC              = require "mqtt-json-rpc"
{ EventEmitter } = require "events"

class TaskManager extends EventEmitter
	constructor: (mqtt) ->
		super mqtt

		@rpc        = new RPC mqtt
		@registered = []
		@queue      = async.queue @handleTask

	handleTask: ({ name, fn, params }, cb) =>
		fn ...params
			.then =>
				cb()

				@emit "done",
					name:   name
					params: params
			.catch (error) =>
				@emit "error", error
				cb error

	addTask: ({ name, fn, params }) ->
		@queue.push
			name:   name
			fn:     fn
			params: params

		@emit "added",
			name:      name
			params:    params
			remaining: @getRemainingTasks()

	getRemainingTasks: ->
		[]
			.concat @queue.workersList().map ({ data }) ->
				name:   data.name
				params: data.params
			.concat @queue._tasks.toArray().map ({ name, params }) ->
				name:   name
				params: params

	register: (name, fn) ->
		@unregister name if @registered.includes name
		@registered.push name

		@rpc.register name, fn

	unregister: (name) ->
		@rpc.unregister name

module.exports = TaskManager
