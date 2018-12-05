_     = require "lodash"
debug = (require "debug") "app:registerGroupActions"

log            = (require "../lib/Logger") "registerGroupActions"
registerMethod = require "../helpers/registerMethod"

removeGroupFromGroups = (groupToRemove, groups) ->
	newGroups = _.without Object.values(groups), groupToRemove

	_.reduce newGroups, (groupsObj, group, index) ->
		groupsObj[index + 1] = group
		groupsObj
	, {}

module.exports = ({ baseMethod, rpc, state, appUpdater }) ->
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
		appUpdater.queueUpdate state.getGlobalGroups(), state.getGroups()

	onRemoveGroup = (name) ->
		debug "Removing group '#{name}'"

		currentGroups = state.getGroups()

		state.setGroups removeGroupFromGroups name, currentGroups
		appUpdater.queueUpdate state.getGlobalGroups(), state.getGroups()

	registerMethod rpc, "#{baseMethod}/storeGroups", onStoreGroups
	registerMethod rpc, "#{baseMethod}/removeGroup", onRemoveGroup
