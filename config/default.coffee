os    = require "os"
path  = require "path"

module.exports =
	host: os.hostname()

	mqtt:
		host:     process.env.MQTT_ENDPOINT or "localhost"
		port:     process.env.MQTT_PORT     or 1883
		clientId: process.env.MQTT_CLIENTID or os.hostname()
		tls:
			key:  "/certs/client.key"
			cert: "/certs/client.crt"
			ca:   "/certs/ca.crt"
		extraOpts:
			keepalive:          60
			reconnectPeriod:    5000
			rejectUnauthorized: true

	groups:
		path:      path.join os.homedir(), ".groups"
		mqttTopic: "global/collections/groups"

	package:
		path: path.resolve "package.json"

	state:
		sendStateThrottleTime:    10000
		sendAppStateThrottleTime: 3000

	docker:
		layer:
			regex: /(\/(var\/lib\/)?docker\/image\/overlay2\/layerdb\/sha256\/[\w\d]+)/
			maxPullRetries: 5
		socketPath: "/var/run/docker.sock"
		maxRetries: 5
		registry_auth:
			credentials:
				username:      process.env.GITLAB_USER_NAME
				password:      process.env.GITLAB_USER_ACCESS_TOKEN
				serveraddress: "https://index.docker.io/v1"
