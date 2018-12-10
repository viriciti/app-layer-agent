debug = (require "debug") "app:registerDeviceActions"

registerFunction = require "../helpers/registerFunction"

module.exports = ({ baseName, rpc, state }) ->
	onRefreshState = ->
		debug "Refreshing state ..."

		state.throttledSendState()
		state.sendNsState()

	registerFunction rpc, "#{baseName}/refreshState", onRefreshState
