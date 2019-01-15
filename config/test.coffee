path       = require "path"
{ random } = require "lodash"

module.exports =
	mqtt:
		port:            random 5000, 5500
		clientId:        "test-device"
		extraOptions:
			reconnectPeriod: 100

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
