debug                    = (require "debug") "app:test:container"
{ map }                  = require "lodash"
{ uniqueNamesGenerator } = require "unique-names-generator"

Docker = require "../../src/lib/Docker"

docker     = new Docker
containers = {}

swallowErrors = (promise) ->
	promise
		.then ->
			Promise.resolve()
		.catch (error) ->
			debug "Swallowing error: #{error.message}"
			Promise.resolve()

generateName = ->
	"agent-#{uniqueNamesGenerator "-", true}"

createTestContainer = (options) ->
	name    = generateName()
	options = Object.assign {},
		useNative: true
		autoStart: false
	, options

	if options.useNative
		await docker.dockerode.createContainer
			name:  name
			Image: "hello-world"
	else
		await docker.createContainer
			name:  name
			Image: "hello-world"

	container        = docker.dockerode.getContainer name
	containers[name] = container

	if options.autoStart
		if options.useNative
			await container.start()
		else
			await docker.startContainer id: name

	container: containers[name]
	name:      name

removeAllTestContainers = ->
	await Promise.all map containers, (container, name) ->
		swallowErrors container.remove force: true

	containers = []

module.exports = {
	createTestContainer
	removeAllTestContainers
}
