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
		path: path.resolve os.homedir(), ".groups"

	state:
		sendStateThrottleTime:    10000
		sendAppStateThrottleTime: 3000

	docker:
		allowContainerRemoval: true
		minWaitingTime:        5 * 1000 * 60  # 5 minutes
		maxWaitingTime:        15 * 1000 * 60 # 15 minutes
		maxRetries:            5
		socketPath: "/var/run/docker.sock"
		registryAuth:
			credentials:
				username:      process.env.GITLAB_USER_NAME
				password:      process.env.GITLAB_USER_ACCESS_TOKEN
				serveraddress: "https://index.docker.io/v1"
