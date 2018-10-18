debug = (require "debug") "app:actions:device"

module.exports = (state) ->
	refreshState = (payload, cb) ->
		debug "Refresh state"

		state.throttledSendState()
		state.sendNsState()

		cb()

	return {
		refreshState
	}
