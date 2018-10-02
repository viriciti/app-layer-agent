_      = require "underscore"
async  = require "async"
config = require "config"
debug  = (require "debug") "app:actions:groups"
fs     = require "fs"

log = (require "../lib/Logger") "groups actions"

module.exports = (state, appUpdater) ->
	storeGroup = (label, cb) ->
		log.info "Storing group `#{label}` in `#{config.groups.path}`"

		currentGroups      = state.getGroups()
		currentGroupsIndex = _(currentGroups).keys().length

		debug "Current groups: #{JSON.stringify currentGroups}, index #{currentGroupsIndex}"

		if _.contains _(currentGroups).values(), label
			log.warn "Group #{label} already there. Skipping groups creation..."
			return cb()

		newGroup = {}
		newGroup[++currentGroupsIndex] = label

		state.setGroups _.extend {}, currentGroups, newGroup

		cb null, "Added group #{JSON.stringify labels}. Queueing update..."

		appUpdater.queueUpdate state.getGlobalGroups(), state.getGroups(), (error) ->
			if error
				log.error "Error in `storeGroup` action: #{error.message}"

	storeGroups = (labels, cb) ->
		log.info "Storing groups #{JSON.stringify labels}"

		currentGroups      = state.getGroups()
		currentGroupsIndex = _(currentGroups).keys().length

		debug "Current groups: #{JSON.stringify currentGroups}, index #{currentGroupsIndex}"

		newGroups =
			_(labels).reduce (groups, label, index) ->
				if _.contains _(currentGroups).values(), label
					log.warn "Group test is already present. Skipping..."
					return groups

				group = {}
				currentGroupsIndex = currentGroupsIndex + 1
				group[currentGroupsIndex] = label
				_(groups).extend groups, group
			, {}

		state.setGroups _.extend {}, currentGroups, newGroups

		cb null, "Added groups #{JSON.stringify labels}. Queueing update..."

		appUpdater.queueUpdate state.getGlobalGroups(), state.getGroups(), (error) ->
			log.error "Error in `storeGroups` action: #{error.message}" if error

	removeGroup = (label, cb) ->
		log.info "Removing group", label

		currentGroups = state.getGroups()

		state.setGroups _shiftGroups currentGroups, label

		cb null, "Group #{label} removed correctly! Queueing update..."

		appUpdater.queueUpdate state.getGlobalGroups(), state.getGroups(), (error) ->
			log.error "Error in `removeGroup` action: #{error.message}" if error

	_shiftGroups = (groups, groupToRemove) ->
		newGroups = _.chain(groups)
			.values()
			.without groupToRemove
			.value()

		_(newGroups).reduce (groupsObj, group, index) ->
			groupsObj[++index] = group
			groupsObj
		, {}

	return {
		storeGroup
		storeGroups
		removeGroup
	}
