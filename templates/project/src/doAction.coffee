doAction = require('pantheon-helpers').doAction
couchUtils = require('./couchUtils')
actionHandlers = require('./actions')
validationFns = require('./validation')
shared = require('./shared')

###
change this to the db where you are storing your documents.
If your system uses more than one database, export multiple doAction functions,
one for each databasae
###
dbName = 'DBNAME' 

getDocType = shared.getDocType 

prepDoc = shared.prepDoc

shouldSkipValidationForUser = (actor) ->
    """
    Whether to skip calling validation functions for this user.
    Usually return true for something like a system user.
    """
    return false

module.exports = doAction(couchUtils,
                          dbName,
                          actionHandlers,
                          validationFns,
                          getDocType,
                          prepDoc,
#                         shouldSkipValidationForUser
                         )
