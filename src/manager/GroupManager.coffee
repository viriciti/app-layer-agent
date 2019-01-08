{ without }  = require "lodash"

class GroupManager
	constructor: ->
		@groups = []

	updateGroups: (groups) ->
		@groups = without groups, "default"
		@groups = ["default", @groups...]
		@ensureGroupsOrder()

	getGroups: ->
		@groups

	ensureGroupsOrder: ->
		@groups = without @groups, "default"
		@groups = ["default", ...@groups]
		@groups

module.exports = GroupManager
