_     = require "underscore"
debug = (require "debug") "app:actionsMap"
{
	containersActions
	imagesActions
	deviceActions
	groupsActions
} = require "../actions"

log = (require "../lib/Logger") "actionMap"

module.exports = (docker, state, updater) ->
	execute = ({ action, payload }, cb) ->
		debug "Execute action `#{action}`, payload: #{JSON.stringify payload}"

		unless actionsMap[action]
			error = "Action #{action} is not implemented. Not executing it"
			log.error error
			return cb()

		actionsMap[action](payload, cb)

	actionsMap = _.extend(
		{},
		(containersActions docker, state),
		(imagesActions docker, state),
		(deviceActions state),
		(groupsActions state, updater)
	)

	return { execute }
