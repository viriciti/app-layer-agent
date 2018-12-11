_     = require "lodash"
debug = (require "debug") "app:registerGroupActions"

registerFunction = require "../helpers/registerFunction"

module.exports = ({ baseName, rpc, state, appUpdater }) ->
	onStoreGroups = (names) ->
		debug "Storing groups '#{JSON.stringify names}'"

		state.setGroups state.getGroups().concat names
		state.sendNsState groups: state.getGroups()
		appUpdater.queueUpdate state.getGlobalGroups(), state.getGroups()

	onRemoveGroup = (name) ->
		debug "Removing group '#{name}'"

		currentGroups = state.getGroups()

		state.setGroups _.without currentGroups, name
		state.sendNsState groups: state.getGroups()
		appUpdater.queueUpdate state.getGlobalGroups(), state.getGroups()

	registerFunction rpc, "#{baseName}/storeGroups", onStoreGroups
	registerFunction rpc, "#{baseName}/removeGroup", onRemoveGroup
