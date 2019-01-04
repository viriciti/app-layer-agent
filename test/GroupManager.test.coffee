assert = require "assert"

GroupManager = require "../src/manager/GroupManager"

describe.only ".GroupManager", ->
	afterEach ->
		manager        = new GroupManager
		manager.groups = []

		manager.storeGroups()

	it "should always have the default group", ->
		groupManager = new GroupManager
		groups       = await groupManager.getGroups()

		assert.equal groups[0], "default"

	it "should be able to add a group", ->
		groupManager = new GroupManager

		await groupManager.addGroup "beer"
		groups = await groupManager.getGroups()

		assert.deepStrictEqual groups, ["default", "beer"]

	it "should not add duplicate groups", ->
		groupManager = new GroupManager

		await groupManager.addGroup "beer"
		groups = await groupManager.getGroups()
		assert.deepStrictEqual groups, ["default", "beer"]

		await groupManager.addGroup "beer"
		groups = await groupManager.getGroups()
		assert.deepStrictEqual groups, ["default", "beer"]

	it "should not add default group", ->
		groupManager = new GroupManager
		groups       = await groupManager.getGroups()

		assert.deepStrictEqual groups, ["default"]

		await groupManager.addGroup "default"
		assert.deepStrictEqual groups, ["default"]

	it "should be able to remove a group", ->
		groupManager = new GroupManager

		await groupManager.addGroup "beer"
		groups = await groupManager.getGroups()
		assert.deepStrictEqual groups, ["default", "beer"]

		await groupManager.removeGroup "beer"
		groups = await groupManager.getGroups()
		assert.deepStrictEqual groups, ["default"]

	it "should not be able to remove the default group", ->
		groupManager = new GroupManager
		groups       = await groupManager.getGroups()

		assert.deepStrictEqual groups, ["default"]

		await groupManager.removeGroup "default"
		groups = await groupManager.getGroups()
		assert.deepStrictEqual groups, ["default"]

	it "should ensure the order of groups is correct", ->
		groupManager = new GroupManager

		groupManager.groups = ["beer", "default", "a"]
		groupManager.ensureGroupsOrder()
		assert.deepStrictEqual groupManager.groups, ["default", "beer", "a"]

		groupManager.groups = ["default", "a", "beer"]
		groupManager.ensureGroupsOrder()
		assert.deepStrictEqual groupManager.groups, ["default", "a", "beer"]
