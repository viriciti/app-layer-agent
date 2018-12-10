winston = require "winston"

level   = "info"
level   = "error" if process.env.NODE_ENV is "test"
loggers = {}

module.exports = (label) ->
	return loggers[label] if loggers[label]

	loggers[label] = new winston.Logger transports: [
		new winston.transports.Console
			level:     level
			label:     label
			timestamp: true
			colorize:  true
	]
