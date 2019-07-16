fs     = require "fs"
semver = require "semver"

readVersion = (target) ->
	try
		stats = fs.statSync target
		return false if stats.isDirectory()

		version = fs.readFileSync target, "utf-8"
		version = version.trim()
		return version   if semver.valid version
		return undefined unless version.includes "DATAHUB_VERSION"

		version = version
			.substr version.indexOf "DATAHUB_VERSION"
			.split "\n"
			.shift()
			.split "="
			.pop()
			.trim()

		return version if version?.length
	catch error
		throw error unless error.code is "ENOENT"

	undefined

module.exports = ->
    version   = readVersion "/version"
    version or= readVersion "/usr/lib/os-release"

    version
