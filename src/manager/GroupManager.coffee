config                     = require "config"
fs                         = require "fs"
{ without, isPlainObject } = require "lodash"
log                        = (require "../lib/Logger") "GroupManager"

class GroupManager
	constructor: ->
		@groups         = @readGroupsFromFile()
		@configurations = {}

	readGroupsFromFile: ->
		return [] unless config.groups?.fileLocation

		try
			fs.accessSync config.groups.fileLocation
			groups = JSON.parse fs.readFileSync config.groups.fileLocation, "utf8"
			groups = Object.values groups if isPlainObject groups
			groups
		catch error
			log.error error if error.code isnt "ENOENT"
			[]

	updateGroups: (groups) ->
		@groups = groups
		@groups = without @groups, "default"
		@groups = ["default", @groups...]

	updateGroupConfigurations: (collection) ->
		@configurations = { ...collection }

	getGroups: ->
		@groups

	getGroupConfigurations: ->
		@configurations

module.exports = GroupManager
