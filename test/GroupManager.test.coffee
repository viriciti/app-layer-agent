assert = require "assert"
config = require "config"
fs     = require "fs"

GroupManager = require "../src/manager/GroupManager"

describe ".GroupManager", ->
	it "should ensure the order of groups is correct", ->
		groupManager = new GroupManager

		groupManager.updateGroups ["beer", "default", "a"]
		assert.deepStrictEqual groupManager.getGroups(), ["default", "beer", "a"]

		groupManager.updateGroups ["default", "a", "beer"]
		assert.deepStrictEqual groupManager.getGroups(), ["default", "a", "beer"]

	describe ".bc", ->
		it "should read groups file if it exists (object)", ->
			fileLocation = config.groups.fileLocation
			exampleGroups =
				1: "default"
				2: "non-default"

			fs.writeFileSync fileLocation, JSON.stringify exampleGroups
			assert.deepStrictEqual new GroupManager().getGroups(), ["default", "non-default"]
			fs.writeFileSync fileLocation, JSON.stringify {}

		it "should read groups file if it exists (array)", ->
			fileLocation = config.groups.fileLocation
			exampleGroups = ["default", "non-default"]

			fs.writeFileSync fileLocation, JSON.stringify exampleGroups
			assert.deepStrictEqual new GroupManager().getGroups(), ["default", "non-default"]
			fs.writeFileSync fileLocation, JSON.stringify []
