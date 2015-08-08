worker = require('pantheon-helpers').worker
utils = require('pantheon-helpers').utils
_ = require('underscore')
follow = require('follow')
couch_utils = require('./couch_utils')
logger = require('./loggers').worker

handlers = {
}

getDocType = utils.getDocType

# _users worker
db = couch_utils.nano_system_user.use('db_name')
worker.start_worker(logger,
                    db,
                    handlers,
                    getDocType,
                   )
