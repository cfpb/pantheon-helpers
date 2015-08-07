module.exports = (app, dbNames, couchUtils, routePrefix) ->
    ###
    app: the express app
    dbNames: list of all dbs to query for audit entries
    routePrefix: optional prefix for route (e.g.: /kratos, /moirai)
    ###
    audit = require('./api/audit')(dbNames, couchUtils)
    routePrefix or= ''

    app.get(routePrefix + '/audit', audit.handleGetAudit)
