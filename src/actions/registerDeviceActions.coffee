debug = (require "debug") "app:registerDeviceActions"

registerFunction = require "../helpers/registerFunction"

module.exports = ({ rpc, state }) ->
	onRefreshState = ->
		debug "Refreshing state ..."

		state.throttledSendState()
		state.sendNsState()

		Promise.resolve()

	registerFunction
		fn:   onRefreshState
		name: "refreshState"
		rpc:  rpc
