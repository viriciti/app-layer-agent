{ random, take, isArray, isPlainObject, clone } = require "lodash"
assert                                          = require "assert"
config                                          = require "config"
spy                                             = require "spy"
{ filterUntaggedImages, getRemovableImages }    = require "@viriciti/app-layer-logic"

Docker                                           = require "../src/lib/Docker"
{ createTestContainer, removeAllTestContainers } = require "./utils/container"
delay                                            = require "./utils/delay"

mockDockerPull = (docker, returnStatusCode = 200) ->
	throw new Error "Invalid Docker client" unless docker instanceof Docker

	docker
		.dockerode
		.pull = (name, options, cb) ->
			setTimeout ->
				error            = new Error
				error.statusCode = returnStatusCode
				error.json       = {}

				cb error
			, random 100, 500

	docker

describe ".Docker", ->
	after ->
		removeAllTestContainers()

	it "should list removable images", ->
		{ allImages, runningContainers } = require "../meta/running-images"
		toRemove                         = getRemovableImages runningContainers, allImages

		assert.deepEqual toRemove, [ 'asdf:2.0.0', 'dingen:1.0.0', 'dingen:0.0.1' ]

	it "should list untagged images", ->
		stubImages = [
			{
				Containers:  -1,
				Created:     1528295245,
				Id:          'sha256:0d0f6d41a6205875e486f672eacaa7570ce77bcc6ac1399ac56ae4e4776dc3c4',
				Labels:      null,
				ParentId:    'sha256:4c16a03f6e231e73f942f6a215c2c2181d2ff7b15d006ca5563a6fa7018a2cda',
				RepoDigests: [ '<none>@<none>' ],
				RepoTags:    [ '<none>:<none>' ],
				SharedSize:  -1,
				Size:        1630462905,
				VirtualSize: 1630462905
			},
			{
				Containers:  -1,
				Created:     1528237056,
				Id:          'sha256:87f1a6e84e0012a52c1a176619256c3f0222591b78a266188f9fc983a383b64a',
				Labels:      null,
				ParentId:    '',
				RepoDigests: [ 'mongo@sha256:3a09cd85fb4e76f1d5832f9ea1d4e7481f76e807389b7d8ea6ac4d4ba96f83e5' ],
				RepoTags:    null,
				SharedSize:  -1,
				Size:        367640570,
				VirtualSize: 367640570 },
			{
				Containers:  -1,
				Created:     1528233696,
				Id:          'sha256:578c3e61a98cb5720e7c8fc152017be1dff373ebd72a32bbe6e328234efc8d1a',
				Labels:      null,
				ParentId:    '',
				RepoDigests: [ 'ubuntu@sha256:885bb6705b01d99544ddb98cbe4e4555d1efe1d052cef90832e72a0688ac6b37' ],
				RepoTags:    [ 'ubuntu:14.04' ],
				SharedSize:  -1,
				Size:        223367926,
				VirtualSize: 223367926
			},
		]

		untagged = filterUntaggedImages stubImages

		assert.deepEqual untagged, take stubImages, 2

	it "should not retry if status code is 500", ->
		docker = new Docker
		docker = mockDockerPull docker, 500

		try
			await docker.pullImage "hello-world"
		catch error
			assert.equal error.statusCode, 500

	it "should retry if status code is 502", ->
		docker                             = new Docker
		docker                             = mockDockerPull docker, 502
		date                               = Date.now()
		{ minWaitingTime, maxWaitingTime } = config.docker.retry
		{ maxAttempts }                    = config.docker.retry
		expectedMinimumWaitingTime         = ((maxWaitingTime - minWaitingTime) + minWaitingTime) * maxAttempts

		try
			await docker.pullImage "hello-world"
		catch error
			return new Error "Callback was called too early" if (Date.now() - date) > expectedMinimumWaitingTime

			assert.equal error.statusCode, 502

	it "should be able to return a shortened image id", ->
		docker    = new Docker

		hash      = "sha256:87f1a6e84e0012a52c1a176619256c3f0222591b78a266188f9fc983a383b64a"
		shortened = docker.getShortenedImageId hash
		assert.equal shortened, "87f1a6e84e00"

		hash      = "87f1a6e84e0012a52c1a176619256c3f0222591b78a266188f9fc983a383b64a"
		shortened = docker.getShortenedImageId hash
		assert.equal hash, shortened

	it "should be able to get info", ->
		docker = new Docker
		info   = await docker.getDockerInfo()

		assert.ok info.apiVersion
		assert.ok info.version
		assert.ok info.kernel

	it "should be able to list images", ->
		docker = new Docker
		images = await docker.listImages()

		assert.ok isArray images

	it "should be able to list containers", ->
		docker     = new Docker
		containers = await docker.listContainers()

		assert.ok isPlainObject containers

	it "should inspect containers when listing", ->
		new Promise (resolve) ->
			docker                    = new Docker
			getContainerByName        = docker.getContainerByName
			docker.getContainerByName = spy ->
				resolve() if @getContainerByName.called
				getContainerByName ...arguments

			docker.listContainers()

	it "should check for authentication", ->
		docker = new Docker
		return @skip() unless docker.isAuthenticationEnabled()

		credentials = clone config.docker.registryAuth.credentials
		invalid     = { ...credentials, username: "this-does-not-exist", password: "*****" }

		config.docker.registryAuth.credentials = invalid
		assert.rejects ->
			docker.verifyAuthentication()
		, /incorrect username or password/i

		config.docker.registryAuth.credentials = credentials
		assert.doesNotReject ->
			docker.verifyAuthentication()
		,
			/incorrect username or password/i
			"Did you configure GitLab (Docker) credentials?"

	it "should be able to pull an image", ->
		@timeout 10000

		docker = new Docker

		assert.doesNotReject ->
			docker.pullImage name: "hello-world:latest"

	it "should be able to create a container", ->
		docker = new Docker

		await docker.createContainer
			name:  "test-container"
			Image: "hello-world"

		await delay 1000
		await docker
			.dockerode
			.getContainer "test-container"
			.remove force: true

	it "should return an empty array if container has no logs", ->
		docker   = new Docker
		{ name } = await createTestContainer autoStart: false

		logs = await docker.getContainerLogs name

		assert.ok isArray logs
		assert.equal logs.length, 0

	it "should be able to start a container", ->
		docker   = new Docker
		{ name } = await createTestContainer()

		await docker.startContainer name

	it "should be able to get container logs", ->
		docker   = new Docker
		{ name } = await createTestContainer autoStart: true

		assert.ok isArray await docker.getContainerLogs name

	it "should be able to restart a container", ->
		docker   = new Docker
		{ name } = await createTestContainer()

		await docker.restartContainer name

	it "should be able to remove a container", ->
		docker   = new Docker
		{ name } = await createTestContainer()

		await delay 1000
		await docker.removeContainer
			id:    name
			force: true
