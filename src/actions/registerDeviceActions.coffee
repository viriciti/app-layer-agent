path  = require "path"
debug = (require "debug") "app:registerDeviceActions"

module.exports = ({ baseMethod, rpc, state }) ->
	onRefreshState = () ->
		debug "Refreshing state ..."

		state.throttledSendState()
		state.sendNsState()

	rpc.register path.join(baseMethod, "refreshState"),  onRefreshState
