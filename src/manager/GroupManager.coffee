{ without }  = require "lodash"

class GroupManager
	constructor: ->
		@groups = []

	updateGroups: (groups) ->
		@groups = without groups, "default"
		@groups = ["default", @groups...]

	getGroups: ->
		@groups

module.exports = GroupManager
