MQTTPattern = require "mqtt-pattern"

module.exports = (client, subscribeTo) ->
	new Promise (resolve, reject) ->
		onMessage = (topic, message) ->
			return unless MQTTPattern.matches subscribeTo, topic

			try
				resolve JSON.parse message.toString()
			catch error
				reject error

		onOffline = ->
			client
				.removeListener "message", onMessage
				.removeListener "offline", onOffline

		client
			.on "message", onMessage
			.on "offline", onOffline

		client.subscribe subscribeTo
