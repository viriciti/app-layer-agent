assert  = require "assert"
mockery = require "mockery"

mockNetworkInterfaces = ->
	lo: [
		address:  "127.0.0.1"
		netmask:  "255.0.0.0"
		family:   "IPv4"
		mac:      "00:00:00:00:00:00"
		internal: true
		cidr:     "127.0.0.1/8"
	,
		address:  "::1",
		netmask:  "ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff"
		family:   "IPv6"
		mac:      "00:00:00:00:00:00"
		internal: true
		cidr:     "::1/128"
	]
	helloworld: [
		address:  "127.0.0.1"
		netmask:  "255.0.0.0"
		family:   "IPv4"
		mac:      "00:00:00:00:00:00"
		internal: true
		cidr:     "127.0.0.1/8"
	,
		address:  "::1",
		netmask:  "ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff"
		family:   "IPv6"
		mac:      "00:00:00:00:00:00"
		internal: true
		cidr:     "::1/128"
	]
	eth0: [
		address:  "192.168.1.254"
		netmask:  "255.255.255.0"
		family:   "IPv4"
		mac:      "01:02:03:0a:0b:0c"
		internal: false
		cidr:     "192.168.1.254/24"
	,
		address:  "fe80::a00:27ff:fe4e:66a1"
		netmask:  "ffff:ffff:ffff:ffff::"
		family:   "IPv6"
		mac:      "01:02:03:0a:0b:0c"
		internal: false
		cidr:     "fe80::a00:27ff:fe4e:66a1/64"
	]
	tun0: [
		address:  "10.200.0.45"
		cidr:     "10.200.0.45/32"
		family:   "IPv4"
		internal: false
		mac:      "01:00:00:00:00:00"
		netmask:  "255.255.255.255"
	,
		address:  "::1"
		netmask:  "ffff:ffff:ffff:ffff::"
		family:   "IPv6"
		mac:      "01:00:00:00:00:00"
		scopeid:  5
		internal: false
		cidr:     "::1/128"
	]
	tun1: [
		address:  "10.200.0.50"
		cidr:     "10.200.0.50/32"
		family:   "IPv4"
		internal: false
		mac:      "01:00:00:00:00:00"
		netmask:  "255.255.255.255"
	,
		address:  "::1"
		netmask:  "ffff:ffff:ffff:ffff::"
		family:   "IPv6"
		mac:      "01:00:00:00:00:00"
		scopeid:  5
		internal: false
		cidr:     "::1/128"
	]

describe ".getIPAddresses", ->
	getIPAddresses = undefined
	source         = "../src/helpers/getIPAddresses"

	before ->
		mockery.registerMock "os", networkInterfaces: mockNetworkInterfaces
		mockery.enable
			useCleanCache:      true
			warnOnReplace:      false
			warnOnUnregistered: false

	after ->
		mockery.disable()

	beforeEach ->
		delete require.cache[source]
		getIPAddresses = require source

	it "should use interface name as key", ->
		addresses = getIPAddresses()
		names     = Object.keys addresses

		assert.ok names.includes "eth0"
		assert.ok names.includes "tun0"

	it "should only include ipv4 addresses", ->
		{ eth0, tun0 } = getIPAddresses()

		assert.equal eth0, "192.168.1.254"
		assert.equal tun0, "10.200.0.45"

	it "should support more than one VPN address", ->
		{ tun0, tun1 } = getIPAddresses()

		assert.ok tun0
		assert.ok tun1

	it "should not include internal addresses", ->
		{ helloworld } = getIPAddresses()

		assert.ifError helloworld
