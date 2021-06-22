log   = require("./lib/Logger") "main"
Agent = require "./Agent"

log.info "Booting up Agent ..."

agent = new Agent
agent
	.start()
	.then ->
		log.info "Booted up correctly"

process.on "unhandledRejection", (reason, promise) ->
	log.error "Caught an unhandled rejection with reason: #{reason}"
	log.error "Promise:"
	console.log promise
	process.exit 1
