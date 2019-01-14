MQTTPattern                      = require "mqtt-pattern"
assert                           = require "assert"
mosca                            = require "mosca"
spy                              = require "spy"
{ random, isArray, every, some } = require "lodash"

Client = require "../src/Client"
doneAfter = (calls, done) ->
	throw new Error "Minimum call count is 1"  if calls < 1
	throw new Error "Maximum call count is 15" if calls > 15

	watcher  = spy (error) ->
		done() if (watcher.callCount + 1) >= calls

	watcher

describe ".Client", ->
	port        = random 5000, 10000
	server      = null
	mqttOptions = null

	before (done) ->
		server      = new mosca.Server port: port
		mqttOptions =
			clientId:        "app-layer-agent-tester"
			port:            port
			reconnectPeriod: 100

		server.once "ready", done

	after ->
		server.close()

	it "should be able to connect", ->
		client = new Client mqttOptions
		client.connect()

	it "should have a last will and testament (LWT)", ->
		client                     = new Client mqttOptions
		{ topic, payload, retain } = client.getWill()

		assert.ok MQTTPattern.matches "devices/+/status", topic
		assert.ok payload
		assert.ok retain

	it "should support placeholders", ->
		{ clientId } = mqttOptions
		client       = new Client mqttOptions
		topic        = client.expandTopic "test/{id}/abc"
		expected     = "test/#{clientId}/abc"

		assert.equal topic, expected

	it "should replace placeholders when subscribing", ->
		client       = new Client mqttOptions
		{ clientId } = mqttOptions
		granted      = await client.subscribe "test/{id}/ok"

		assert.ok clientId
		assert.ok isArray granted
		assert.equal granted.length, 1

		{ topic } = granted[0]
		assert.equal topic, "test/#{clientId}/ok"

	it "should support mqtt patterns in topic", (done) ->
		client       = new Client mqttOptions
		{ clientId } = mqttOptions
		done         = doneAfter 3, done

		client.once "test/{id}/ok", done
		client.once "test/+/ok",    done
		client.once "test/#",       done

		client
			.subscribe "test/{id}/ok"
			.then ->
				server.publish
					topic:   "test/#{clientId}/ok"
					message: null

		null

	it "should throw if attempting to fork an unconnected client", ->
		assert.throws ->
			client = new Client mqttOptions
			client.fork()

	it "should allow mqtt instance to be extracted", ->
		client = new Client mqttOptions

		await client.connect()
		forked = client.fork()

		assert.equal client.mqtt, forked

	it "should be able reconnect", (done) ->
		done   = doneAfter 3, done
		client = new Client mqttOptions

		client
			.connect()
			.then ->
				client
					.fork()
					.once "offline",   done
					.once "close",     done
					.once "reconnect", done

				server.once "clientConnected", (socket) ->
					socket.close()

		null

	it "should remove listeners when client connection closes", (done) ->
		client = new Client { ...mqttOptions, reconnectPeriod: 0 }

		client
			.connect()
			.then ->
				forked     = client.fork()
				expected   = ["packetreceive", "error", "reconnect", "offline"]
				nameInList = (name) -> name in Object.keys forked._events

				forked
					.once "connect", ->
						# fails if any of the expected names
						# does not appear in the events list
						assert.ok every expected, nameInList
					.once "close", (reason) ->
						# fails if any of the expected names
						# appears in the events list
						assert.equal false, some expected, nameInList
						done()

				server.once "clientConnected", (socket) ->
					socket.close()

		null
