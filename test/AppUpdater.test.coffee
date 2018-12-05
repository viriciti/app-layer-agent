# (require "leaked-handles").set {
# 	fullStack: true
# 	timeout: 30000
# 	debugSockets: true
# }

test       = require "tape"
AppUpdater = require "../src/manager/AppUpdater"

test "AppUpdater 1", (t) ->
	updater = AppUpdater {}, publishNamespacedState: ->

	t.comment "Test groups when size is 1 and groups is not default"
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
		t.equal error.message
		, "Size of global groups is 1, but the group is not default. Global groups are misconfigured!"
		, "Should callback immediately when group size is 1 but group is not 'default'"
		t.end()
