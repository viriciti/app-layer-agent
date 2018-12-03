os    = require "os"
path  = require "path"

module.exports =
	mqtt:
		host:     process.env.MQTT_ENDPOINT or "localhost"
		port:     process.env.MQTT_PORT     or 1883
		clientId: os.hostname()
		tls:
			key:  process.env.TLS_KEY
			cert: process.env.TLS_CERT
			ca:   process.env.TLS_CA
		extraOpts:
			keepalive:          60
			reconnectPeriod:    5000
			rejectUnauthorized: true
		actions:
			basePath: "actions/"

	groups:
		path: path.join os.homedir(), ".groups"

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
