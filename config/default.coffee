os = require "os"

getEnv = (name, defaultValue) ->
	process.env["APP_LAYER_#{name}"] or
	process.env[name]                or
	defaultValue

module.exports =
	pruneImageTimeout: 20 * 1000

	queueUpdateInterval: 10 * 1000

	heartbeatMinInterval: 5 * 1000

	mqtt:
		host:     getEnv "MQTT_ENDPOINT", "localhost"
		port:     getEnv "MQTT_PORT",     1883
		clientId: os.hostname()
		tls:
			key:  getEnv "TLS_KEY"
			cert: getEnv "TLS_CERT"
			ca:   getEnv "TLS_CA"
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
		socketPath: if getEnv "USE_DOCKER" then "/var/run/docker.sock" else "/var/run/balena-engine.sock"
		container:
			allowRemoval: true
			whitelist:    ["app-layer-agent", "device-manager"]
		retry:
			minWaitingTime:       5 * 1000 * 60  # 5 minutes
			maxWaitingTime:       15 * 1000 * 60 # 15 minutes
			maxAttempts:          10
			errorCodes:           [500, 502, 503, 504]
			removeCorruptedLayer: true
		registryAuth:
			credentials:
				username:      getEnv "GITLAB_USERNAME",     process.env.GITLAB_USER_NAME
				password:      getEnv "GITLAB_ACCESS_TOKEN", process.env.GITLAB_USER_ACCESS_TOKEN
				serveraddress: "https://index.docker.io/v1"
