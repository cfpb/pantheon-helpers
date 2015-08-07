auditRoutes = require('pantheon-helpers').auditRoutes
couch_utils = require('./couch_utils')

module.exports = (app) ->
  # define routes here. For example:
  # app.get('/sisyphus/boulders', boulders.handleGetBoulders)


  ###
  app: the express app
  dbNames: list of all dbs to query for audit entries
  routePrefix: optional prefix for route (e.g.: /kratos, /moirai)
  ###
  auditRoutes(app, ['DBNAME'], couch_utils, 'ROUTEPREFIX')
