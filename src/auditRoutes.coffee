module.exports = (app, dbNames, couch_utils, routePrefix) ->
    ###
    app: the express app
    dbNames: list of all dbs to query for audit entries
    routePrefix: optional prefix for route (e.g.: /kratos, /moirai)
    ###
    audit = require('./api/audit')(dbNames)
    routePrefix or= ''

    app.get(routePrefix + '/audit', audit.handleGetAudit(dbNames, couch_utils))
