os = require "os"

module.exports = ->
	ifaces = os.networkInterfaces()

	eth0IP  = ifaces.eth0?[0].address  or null
	tun0IP  = ifaces.tun0?[0].address  or null
	wlan0IP = ifaces.wwan0?[0].address or null
	ppp0IP  = ifaces.ppp0?[0].address  or null

	{ eth0IP, tun0IP, wlan0IP, ppp0IP }
