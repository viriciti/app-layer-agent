devicemqtt = require "@tn-group/device-mqtt"

server = devicemqtt {
	host: "localhost"
	port: 1883
	clientId: "serverMock"
}

insertGroupsAction =
	action:  "insertGroups"
	payload: ["group2", "group3"]
	dest:    "viriciti"


server.on "connected", (socket) ->
	socket.send(
		insertGroupsAction
	, (error, response) ->
			console.log "Response: ", response
	, (error, ack) ->
			console.log ack
	)

server.connect()
