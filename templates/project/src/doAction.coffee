doAction = require('pantheon-helpers').doAction
couchUtils = require('./couchUtils')
actionHandlers = require('./actions')
validationFns = require('./validation')
shared = require('./shared')

###
If your app only uses one DB, set dbName to the name of your DB.
You can then call `doAction(actor, docId, action)`
If you leave `dbName = null` then you must specify the
database every time: `doAction(dbName, actor, docId, action)`
###
dbName = null

getDocType = shared.getDocType 

prepDoc = shared.prepDoc

shouldSkipValidationForUser = (actor) ->
    """
    Whether to skip calling validation functions for this user.
    Usually return true for something like a system user.
    """
    return false

module.exports = doAction(dbName,
                          couchUtils,
                          actionHandlers,
                          validationFns,
                          getDocType,
                          prepDoc,
#                         shouldSkipValidationForUser
                         )
