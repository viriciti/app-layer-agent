assert     = require "assert"
AppUpdater = require "../src/manager/AppUpdater"

groups = {}

describe ".AppUpdater", ->
	beforeEach ->
		groups =
			default:
				app1:
					containerName: "app1"
					fromImage: "image1:1.0.0"
					labels:
						group: "somegroup"
						manual: false
				app2:
					containerName: "app2"
					fromImage: "image2:3.1.0"
					labels:
						group: "somegroup"
						manual: false
			name:
				app1:
					containerName: "app1"
					fromImage: "image1:2.1.0"
					labels:
						group: "somegroup"
						manual: false
				app2:
					containerName: "app2"
					fromImage: "image2:4.1.0"
					labels:
						group: "somegroup"
						manual: false

	afterEach ->
		groups = {}

	it "should error if default group does not exist", (done) ->
		delete groups["default"]

		updater = new AppUpdater

		updater.update groups, [], (error) ->
			assert.ok error.message.match /no default group/i
			done()

	it "should error if default group is not the first group", (done) ->
		updater      = new AppUpdater
		groups       =
			name:    groups.name
			default: groups["default"]

		updater.update groups, [], (error) ->
			assert.ok error.message.match /Default group must appear first/i
			done()
