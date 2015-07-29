auditRoutes = require('pantheon-helpers').auditRoutes
couch_utils = require('./couch_utils')

module.exports = (app) ->
  # define routes here. For example:
  # app.get('/sisyphus/boulders', boulders.handleGetBoulders)

  auditRoutes(app, ['DBNAME'], couch_utils, 'ROUTEPREFIX')
