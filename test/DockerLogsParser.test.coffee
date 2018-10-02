# (require 'leaked-handles').set {
# 	fullStack: true
# 	timeout: 30000
# 	debugSockets: true
# }

test             = require 'tape'
DockerLogsParser = require '../src/lib/DockerLogsParser'

### Testing template

test 'What component aspect are you testing?', (assert) ->
	actual = 'What is the actual output?'
	expected = 'What is the expected output?'

	assert.equal actual, expected, 'What should the feature do?'

	assert.end()

###############################################################

setup = ->
	docker = {}
	docker.getImageByName = (name, cb) ->
		if name is '48b5124b2768d2b917edcb640435044a97967015485e812545546cbed5cf0234'
			return cb null, { tags: ['hello-world:latest'] }
		if name is '48b5124b2768d2b917edcb640435044a97967015485e812545546cbed5cf0233'
			return cb null, { tags: ['hello-world:latest'] }
	parser = new DockerLogsParser docker
	return parser


test 'parse logs coming from handling an image', (assert)->
	parser = setup()

	tests = [
			{
				testType: 'create'
				toTest:
					id: 'hello-world:latest'
					Actor:
						ID: 'hello-world:latest'
						Attributes: { name: 'hello-world' }
					Type: 'image'
					Action: 'pull'
					time: 1486389676
				expected: { message: 'Pulled image hello-world:latest', time: 1486389676 * 1000, type: "info" }
			},

			{
				testType: 'untag'
				toTest:
					id: 'sha256:48b5124b2768d2b917edcb640435044a97967015485e812545546cbed5cf0234'
					Actor:
						ID: 'sha256:48b5124b2768d2b917edcb640435044a97967015485e812545546cbed5cf0233'
						Attributes: { name: 'sha256:48b5124b2768d2b917edcb640435044a97967015485e812545546cbed5cf0233' }
					Type: 'image',
					Action: 'untag',
					time: 1486390186
				expected: { message: 'An image has been untagged', time: 1486390186 * 1000, type: "info" }
			},

			{
				testType: 'tag'
				toTest:
					id: 'sha256:51d6b0f378041567e382a6e34fcbf92bb7cdd995df618233300c3b178d0f5082'
					Actor:
						ID: 'sha256:51d6b0f378041567e382a6e34fcbf92bb7cdd995df618233300c3b178d0f5082'
						Attributes: { name: 'alpine:3.9.8' }
					Type: 'image'
					Action: 'tag'
					time: 1486390644
				expected: { message: 'Tagged image alpine with tag 3.9.8', time: 1486390644 * 1000, type: "info"}
			},

			{
				testType: 'remove'
				toTest:
					id: 'sha256:48b5124b2768d2b917edcb640435044a97967015485e812545546cbed5cf0233'
					Actor:
						ID: 'sha256:48b5124b2768d2b917edcb640435044a97967015485e812545546cbed5cf0233'
						Attributes: { name: 'sha256:48b5124b2768d2b917edcb640435044a97967015485e812545546cbed5cf0233' }
					Type: 'image'
					Action: 'delete'
					time: 1486390930
				expected: { message: 'An image has been removed', time: 1486390930 * 1000, type: "info"}
			}
	]

	tests.forEach (test) ->
		parsedMessage = parser.parseLogs test.toTest
		assert.deepEqual parsedMessage, test.expected,
			"should parse the logs and return a meaningful message when Actions is #{test.testType}"

	assert.end()


test 'parse logs coming from handling a container', (assert) ->
	parser = setup()

	tests = [
		{
			testType: 'destroy'
			toTest:
				id: 'd56979dd69f7177fa9c1096ce260b77f011036f9aa910123ba047e26dffe932c'
				Actor:
					ID: 'd56979dd69f7177fa9c1096ce260b77f011036f9aa910123ba047e26dffe932c'
					Attributes:
						image: 'sha256:32d3ac0816fcb1e9daaa56bd3bb7805c091b73d295c525f21555a9eb471506ee'
						name: 'kickass_hawking'
				Type: 'container'
				Action: 'destroy'
				time: 1486397270
			expected: { message: 'A container has been destroyed', time: 1486397270  * 1000, type: "info"}
		},

		{
			testType: 'create'
			toTest:
				id: '6c3d8a67ffe4110f3651459e0732cc0fe37a6fb770b40e22b140c85a5031ce42'
				Actor:
					ID: '6c3d8a67ffe4110f3651459e0732cc0fe37a6fb770b40e22b140c85a5031ce'
					Attributes: { image: 'redis', name: 'test' }
				Type: 'container'
				Action: 'create'
				time: 1486397561
			expected: { message: 'Created container test from image redis', time: 1486397561 * 1000, type: "info" }
		},

		{
			testType: 'start'
			toTest:
				id: '6c3d8a67ffe4110f3651459e0732cc0fe37a6fb770b40e22b140c85a5031ce42'
				Actor:
					ID: '6c3d8a67ffe4110f3651459e0732cc0fe37a6fb770b40e22b140c85a5031ce'
					Attributes: { image: 'redis', name: 'test' }
				Type: 'container'
				Action: 'start'
				time: 1486397561
			expected: { message: 'Started container test', time: 1486397561 * 1000, type: "info" }
		},

		{
			testType: 'stop'
			toTest:
				id: '6c3d8a67ffe4110f3651459e0732cc0fe37a6fb770b40e22b140c85a5031ce42'
				Actor:
					ID: '6c3d8a67ffe4110f3651459e0732cc0fe37a6fb770b40e22b140c85a5031ce42'
					Attributes: { image: 'redis', name: 'test' }
				Type: 'container'
				Action: 'stop'
				time: 1486397980
			expected: { message: 'Stopped container test', time: 1486397980 * 1000, type: "info" }
		}
	]

	tests.forEach (test) ->
		parsedMessage = parser.parseLogs test.toTest
		assert.deepEqual parsedMessage, test.expected,
			"should parse the logs and return a meaningful message when Actions is #{test.testType}"

	assert.end()
