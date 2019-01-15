assert   = require "assert"
mosca    = require "mosca"
config   = require "config"
{ once } = require "lodash"

Agent = require "../src/Agent"

describe.only ".Agent", ->
	server = null

	before (done) ->
		server = new mosca.Server port: config.mqtt.port

		server.once "ready", done

	after ->
		server.close()

	it "should be able to start", ->
		agent = new Agent

		agent.start()

	it "should subscribe to the commands and groups topic", ->
		agent        = new Agent
		{ clientId } = config.mqtt

		await agent.start()

		subscribedTopics = agent.client.subscribedTopics

		assert.ok subscribedTopics.includes "commands/#{clientId}/+"
		assert.ok subscribedTopics.includes "devices/#{clientId}/groups"

	it "should subscribe to collections topic after receiving groups", (done) ->
		agent        = new Agent
		{ clientId } = config.mqtt
		done         = once done

		agent.start()

		server.on "published", ({ topic, payload }) ->
			return unless topic.endsWith "new/subscribes"

			payload = JSON.parse payload

			if payload.topic is "global/collections/+"
				assert.ok agent.client.subscribedTopics.includes "global/collections/+"
				return done()

			unless payload.topic is "devices/#{clientId}/groups"
				return

			server.publish
				topic:   "devices/#{clientId}/groups"
				payload: JSON.stringify ["default"]

		subscribedTopics = agent.client.subscribedTopics

		assert.equal clientId, config.mqtt.clientId
		assert.equal false, subscribedTopics.includes "global/collections/+"
		assert.ok subscribedTopics.includes "commands/#{clientId}/+"
		assert.ok subscribedTopics.includes "devices/#{clientId}/groups"

	it "should send online status when connecting", (done) ->
		agent        = new Agent
		{ clientId } = config.mqtt
		done         = once done

		agent.start()

		server.on "published", ({ topic, payload }) ->
			return done() if topic is "devices/#{clientId}/status"

	it "should send state after receiving groups", (done) ->
		agent        = new Agent
		{ clientId } = config.mqtt
		done         = once done

		agent.start()

		server.on "published", ({ topic, payload }) ->
			if (
				topic is "devices/test-device/state" and
				agent.client.subscribedTopics.includes "global/collections/+"
			)
				return done()

			# wait for client to subscribe to groups topic
			return unless topic.endsWith "new/subscribes"

			payload = JSON.parse payload
			return unless payload.topic is "devices/#{clientId}/groups"

			server.publish
				topic:   "devices/#{clientId}/groups"
				payload: JSON.stringify ["default"]
