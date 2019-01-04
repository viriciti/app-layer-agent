debug = (require "debug") "app:registerGroupActions"

registerFunction = require "../helpers/registerFunction"

module.exports = ({ baseName, rpc, state, appUpdater, groupManager }) ->
	onStoreGroups = (names) ->
		debug "Storing groups '#{JSON.stringify names}'"

		groupManager.addGroups names
		state.sendNsState groups: groupManager.getGroups()
		appUpdater.queueUpdate state.getGlobalGroups(), groupManager.getGroups()

	onRemoveGroup = (name) ->
		debug "Removing group '#{name}'"

		state.removeGroup name
		state.sendNsState groups: groupManager.getGroups()
		appUpdater.queueUpdate state.getGlobalGroups(), groupManager.getGroups()

	registerFunction rpc, "#{baseName}/storeGroups", onStoreGroups
	registerFunction rpc, "#{baseName}/removeGroup", onRemoveGroup
