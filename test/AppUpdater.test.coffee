assert     = require "assert"
{ noop }   = require "lodash"
AppUpdater = require "../src/manager/AppUpdater"

describe ".AppUpdater", ->
	it "should error if default group does not exist", (done) ->
		updater                        = new AppUpdater {}
		updater.publishNamespacedState = noop

		groups =
			somegroup:
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

		deviceGroups = undefined

		updater.update groups, deviceGroups, (error) ->
			assert.equal error.message
			, "Size of global groups is 1, but the group is not default. Global groups are misconfigured!"
			, "Should callback immediately when group size is 1 but group is not 'default'"

			done()
