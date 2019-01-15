assert     = require "assert"
AppUpdater = require "../src/manager/AppUpdater"
Docker     = require "../src/lib/Docker"

groups            = {}
docker            = new Docker
testContainerName = "app-layer-agent-test-container"

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

	after ->
		docker.removeContainer testContainerName

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
			assert.ok error.message.match /default group must appear first/i
			done()

	it "should be able to convert binds to mounts", ->
		updater = new AppUpdater
		binds   = [
			"/version:/root/.version:ro"
			"/docker:/docker"
			"/data:/data"
		]
		expected = [
			ReadOnly: true
			Source:   "/version"
			Target:   "/root/.version"
			Type:     "bind"
		,
			ReadOnly: false
			Source:   "/docker"
			Target:   "/docker"
			Type:     "bind"
		,
			ReadOnly: false
			Source:   "/data"
			Target:   "/data"
			Type:     "bind"
		]

		assert.deepEqual updater.bindsToMounts(binds), expected

	it "should fail to create if host file does not exist", (done) ->
		docker    = new Docker
		updater   = new AppUpdater docker
		appConfig = updater.normalizeAppConfiguration
			restartPolicy: "always",
			containerName:  testContainerName,
			networkMode:   "host",
			fromImage:     "hello-world",
			detached:      false,
			environment:   [],
			privileged:    true,
			version:       "^1.0.0",
			mounts: [
				"/this/will/never/exist/ok:/version/mount"
			],
			applicationName: testContainerName

		docker.createContainer containerProps: appConfig, (error) ->
			assert.ok error
			assert.ok error.message.match /bind source path does not exist/i
			assert.equal error.statusCode, 400
			done()
