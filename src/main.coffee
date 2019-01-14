log   = require("./lib/Logger") "main"
Agent = require "./Agent"

log.info "Booting up Agent ..."

agent = new Agent
agent
	.start()
	.then ->
		log.info "Booted up correctly"
