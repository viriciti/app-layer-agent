# { spawn } = require "child_process"
# test = require "tape"
# os   = require "os"

# { mqttSocket, state, client } = require "../src/main"

# test.only "Socket should be set", (t) ->
	# client.once "connected", (socket) ->
		# setTimeout ->
			# t.equal mqttSocket, socket
			# t.end()
		# , 1500

		# t.equal state.getDeviceId(), os.hostname()

