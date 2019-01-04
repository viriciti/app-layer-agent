fs           = require "fs"
config       = require "config"
{ without }  = require "lodash"
promisifyAll = require "util-promisifyall"

log = require("../lib/Logger") "GroupManager"
fs  = promisifyAll fs

class GroupManager
	constructor: ->
		@groups       = ["default"]
		@fileLocation = config.groups.fileLocation

	storeGroups: ->
		await fs.writeFileAsync @fileLocation, JSON.stringify @groups

	getGroups: ->
		await @storeGroups() unless await fs.accessAsync @fileLocation

		try
			@groups = JSON.parse await fs.readFileAsync @fileLocation, "utf8"
		catch
			log.error "Error when parsing groups file, setting default groups ..."
			await @storeGroups()

		@groups = Object.values @groups unless Array.isArray @groups

		@ensureGroupsOrder()
		@groups

	addGroup: (name) ->
		return log.warn "Group '#{name}' is already added"     if @groups.includes name
		return log.warn "Default group is automatically added" if name is "default"

		@groups = @groups.concat name
		await @storeGroups()

	removeGroup: (name) ->
		return log.warn "Group '#{name}' does not exist"  unless @groups.includes name
		return log.warn "Default group cannot be removed" if name is "default"

		@groups = without @groups, name
		await @storeGroups()

	ensureGroupsOrder: ->
		@groups = without @groups, "default"
		@groups = ["default", ...@groups]
		@groups

module.exports = GroupManager
