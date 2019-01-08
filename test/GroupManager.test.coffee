assert = require "assert"

GroupManager = require "../src/manager/GroupManager"

describe ".GroupManager", ->
	it "should ensure the order of groups is correct", ->
		groupManager = new GroupManager

		groupManager.updateGroups ["beer", "default", "a"]
		assert.deepStrictEqual groupManager.getGroups(), ["default", "beer", "a"]

		groupManager.updateGroups ["default", "a", "beer"]
		assert.deepStrictEqual groupManager.getGroups(), ["default", "a", "beer"]
