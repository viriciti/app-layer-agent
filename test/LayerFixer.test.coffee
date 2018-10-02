test = require "tape"

LayerFixer = require "../src/lib/LayerFixer"

regex = /(\/(var\/lib\/)?docker\/image\/overlay2\/layerdb\/sha256\/[\w\d]+)/

test "Layer regex should not return the incorrect path", (t) ->
	paths = [
		"/var/lib/docker/image/overlay2/layerdb/tmp/write-set-123456789"
		"/docker/image/overlay2/layerdb/sha256/9db9d1f00b0dad8297099fcdaa1faf040a5b1f80042ba0482685aeb305e4a124"
	]
	message = "failed to register layer: rename #{paths[0]} #{paths[1]}"
	result  = regex.exec(message).shift()

	t.notEqual result, paths[0]
	t.equal result, paths[1]
	t.end()

test "Layer regex should match conflicting directory", (t) ->
	conflict     = "/var/lib/docker/image/overlay2/layerdb/sha256/9db9d1f00b0dad8297099fcdaa1faf040a5b1f80042ba0482685aeb305e4a124"
	conflictRoot = "/docker/image/overlay2/layerdb/sha256/9db9d1f00b0dad8297099fcdaa1faf040a5b1f80042ba0482685aeb305e4a124"
	message      = "failed to register layer: rename /var/lib/docker/image/overlay2/layerdb/tmp/write-set-123456789 #{conflict}"
	messageRoot  = "failed to register layer: rename /docker/image/overlay2/layerdb/tmp/write-set-123456789 #{conflictRoot}"

	t.equal conflict, regex.exec(message).shift()
	t.equal conflictRoot, regex.exec(messageRoot).shift()
	t.end()

test "Layer regex should not return a match if it is not the correct error", (t) ->
	message = "blabla"

	t.equal null, regex.exec message
	t.end()

test "Layer stream should not handle if non-error", (t) ->
	t.plan 1
	message = "failed to register layer: rename /docker/image/overlay2/layerdb/tmp/write-set-123456789 /docker/image/overlay2/layerdb/sha256/9db9d1f00b0dad8297099fcdaa1faf040a5b1f80042ba0482685aeb305e4a124"

	stream = new LayerFixer regex
	stream.write message, "utf-8", (error) ->
		t.equal error, undefined
		t.end()

test "Layer stream should pass conflicting directory in callback", (t) ->
	t.plan 3
	message =
		error: "failed to register layer: rename /docker/image/overlay2/layerdb/tmp/write-set-123456789 /docker/image/overlay2/layerdb/sha256/9db9d1f00b0dad8297099fcdaa1faf040a5b1f80042ba0482685aeb305e4a124"

	stream = new LayerFixer regex
	stream.on "error", (error) ->
		t.ok error instanceof Error
		t.ok error.conflictingDirectory
		t.equal error.conflictingDirectory, "/docker/image/overlay2/layerdb/sha256/9db9d1f00b0dad8297099fcdaa1faf040a5b1f80042ba0482685aeb305e4a124"
		t.end()

	stream.write message
