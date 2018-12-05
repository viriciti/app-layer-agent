winston = require "winston"

loggers = {}

module.exports = (label) ->
	return loggers[label] if loggers[label]

	loggers[label] = new winston.Logger transports: [
		new winston.transports.Console
			label:     label
			timestamp: true
			colorize:  true
	]
