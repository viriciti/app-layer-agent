test = require 'tape'
_    = require "underscore"

{
	filterUntaggedImages,
	getRemovableImages
} = require "@viriciti/app-layer-logic"

Docker = require "../src/lib/Docker"

config =
	docker:
		socketPath: "/var/run/docker.sock"
		maxRetries: 5
		registry_auth:
			required: false

test "Should list removable images", (t) ->
	{ allImages, runningContainers } = require "../meta/running-images"
	toRemove                         = getRemovableImages runningContainers, allImages
	t.deepEqual toRemove, [ 'asdf:2.0.0', 'dingen:1.0.0', 'dingen:0.0.1' ], "Incorrect images to remove!"
	t.end()

test "Should list untagged images", (t) ->
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
	t.deepEqual untagged, (_(stubImages).first 2), "Should filter out the correct images"
	t.end()

test "Should remove untagged images", (t) ->
	docker = new Docker config.docker
	docker.removeUntaggedImages (error, data) ->
		throw error if error
		docker.dockerEventStream.once "end", ->
			t.end()
		docker.stop()
