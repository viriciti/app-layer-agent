debug = (require "debug") "app:registerGroupActions"

registerFunction = require "../helpers/registerFunction"

module.exports = ({ baseName, rpc, state, appUpdater, groupManager }) ->
	onStoreGroups = (names) ->
		debug "Storing groups '#{JSON.stringify names}'"

		await groupManager.addGroups names
		state.sendNsState groups: await groupManager.getGroups()
		appUpdater.queueUpdate state.getGlobalGroups(), await groupManager.getGroups()

	onRemoveGroup = (name) ->
		debug "Removing group '#{name}'"

		await groupManager.removeGroup name
		state.sendNsState groups: await groupManager.getGroups()
		appUpdater.queueUpdate state.getGlobalGroups(), await groupManager.getGroups()

	registerFunction rpc, "#{baseName}/storeGroups", onStoreGroups
	registerFunction rpc, "#{baseName}/removeGroup", onRemoveGroup
