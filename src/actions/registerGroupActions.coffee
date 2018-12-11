_     = require "lodash"
debug = (require "debug") "app:registerGroupActions"

log              = (require "../lib/Logger") "registerGroupActions"
registerFunction = require "../helpers/registerFunction"

removeGroupFromGroups = (groupToRemove, groups) ->
	newGroups = _.without Object.values(groups), groupToRemove

	_.reduce newGroups, (groupsObj, group, index) ->
		groupsObj[index + 1] = group
		groupsObj
	, {}

module.exports = ({ baseName, rpc, state, appUpdater }) ->
	onStoreGroups = (names) ->
		debug "Storing groups '#{JSON.stringify names}'"

		currentGroups      = state.getGroups()
		currentGroupsIndex = Object.keys(currentGroups).length

		newGroups = names.reduce (groups, label, index) ->
			if Object.values(currentGroups).includes label
				log.warn "Group '#{label}' is already present. Skipping ..."
				return groups

			group                     = {}
			currentGroupsIndex        = currentGroupsIndex + 1
			group[currentGroupsIndex] = label

			Object.assign {}, groups, group
		, {}

		state.setGroups Object.assign {}, currentGroups, newGroups
		state.sendNsState groups: Object.values state.getGroups()
		appUpdater.queueUpdate state.getGlobalGroups(), state.getGroups()

	onRemoveGroup = (name) ->
		debug "Removing group '#{name}'"

		currentGroups = state.getGroups()

		state.setGroups removeGroupFromGroups name, currentGroups
		state.sendNsState groups: Object.values state.getGroups()
		appUpdater.queueUpdate state.getGlobalGroups(), state.getGroups()

	registerFunction rpc, "#{baseName}/storeGroups", onStoreGroups
	registerFunction rpc, "#{baseName}/removeGroup", onRemoveGroup
