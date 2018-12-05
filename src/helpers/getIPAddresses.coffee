os         = require "os"
{ reduce, find } = require "lodash"

module.exports = ->
	reduce os.networkInterfaces(), (addresses, iface, name) ->
		# support ipv4 addresses
		ipv4 = find iface, family: "IPv4"
		return addresses unless ipv4

		# ignore internal addresses
		{ address, internal } = ipv4
		return addresses if internal

		addresses[name] = address
		addresses
	, {}
