debug = (require "debug") "app:actions:device"

log = (require "../lib/Logger") "device actions"

module.exports = (state) ->

	refreshState = (payload, cb) ->
		debug "Refresh state"
		state.throttledSendState()
		state.sendNsState()
		cb()

	return {
		refreshState
	}
