debug = (require "debug") "app:registerDeviceActions"

registerMethod = require "../helpers/registerMethod"

module.exports = ({ baseMethod, rpc, state }) ->
	onRefreshState = ->
		debug "Refreshing state ..."

		state.throttledSendState()
		state.sendNsState()

	registerMethod rpc, "#{baseMethod}/refreshState", onRefreshState
