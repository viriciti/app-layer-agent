_     = require "underscore"
debug = (require "debug") "app:action-map"

log = (require "../lib/Logger") "actionMap"

module.exports = (docker, state, updater) ->
	{
		containersActions
		imagesActions
		deviceActions
		groupsActions
	} = require "../actions"

	execute = ({ action, payload }, cb) ->
		debug "Execute action `#{action}`, payload: #{JSON.stringify payload}"
		if not actionsMap[action]
			error = "Action #{action} is not implemented. Not executing it..."
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
