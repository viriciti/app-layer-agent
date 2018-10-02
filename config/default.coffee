os    = require "os"
path  = require "path"

module.exports =
	host: os.hostname()

	mqtt:
		host: "localhost"
		port: 1883
		clientId: os.hostname()
		extraOpts:
			keepalive: 60
			rejectUnauthorized: true
			reconnectPeriod: 5000

	devicemqtt:
		queueTimeout: 5000 # never touch it

	groups:
		path: "/groups"
		mqttTopic: "global/collections/groups"
		whiteList: ["device-manager", "dev"]

	version:
		path: "/version"

	package:
		path: path.resolve "#{__dirname}/../package.json"

	sendStateThrottleTime: 10000

	docker:
		layer:
			regex: /(\/(var\/lib\/)?docker\/image\/overlay2\/layerdb\/sha256\/[\w\d]+)/
			maxPullRetries: 5
		socketPath: "/var/run/docker.sock"
		maxRetries: 5
		registry_auth:
			required: false

	development: false
