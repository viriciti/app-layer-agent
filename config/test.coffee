path = require "path"

module.exports =
	mqtt:
		clientId: "test-device"

	docker:
		socketPath: "/var/run/docker.sock"
		retry:
			maxAttempts:    2
			minWaitingTime: 1 * 100 # 0.5 second
			maxWaitingTime: 1 * 100 # 0.5 second
		registryAuth:
			required: false

	groups:
		fileLocation: path.resolve "meta", "groups.json"

	state:
		sendStateThrottleTime: 50
