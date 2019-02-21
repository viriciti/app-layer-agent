os = require "os"

module.exports =
	mqtt:
		host:     process.env.MQTT_ENDPOINT or "localhost"
		port:     process.env.MQTT_PORT     or 1883
		clientId: os.hostname()
		tls:
			key:  process.env.TLS_KEY
			cert: process.env.TLS_CERT
			ca:   process.env.TLS_CA
		extraOptions:
			keepalive:          60
			reconnectPeriod:    5000
			rejectUnauthorized: true
		actions:
			baseTopic: "actions/"

	state:
		sendStateThrottleTime:    10000
		sendAppStateThrottleTime: 3000

	queue:
		maxStoredTasks: 15

	docker:
		socketPath: if process.env.USE_BALENA then "/var/run/balena-engine.sock" else "/var/run/docker.sock"
		container:
			allowRemoval: true
			whitelist:    ["app-layer-agent"]
		retry:
			minWaitingTime: 5 * 1000 * 60  # 5 minutes
			maxWaitingTime: 15 * 1000 * 60 # 15 minutes
			maxAttempts:    10
			errorCodes:     [502, 503, 504]
		registryAuth:
			credentials:
				username:      process.env.GITLAB_USERNAME     or process.env.GITLAB_USER_NAME
				password:      process.env.GITLAB_ACCESS_TOKEN or process.env.GITLAB_USER_ACCESS_TOKEN
				serveraddress: "https://index.docker.io/v1"
