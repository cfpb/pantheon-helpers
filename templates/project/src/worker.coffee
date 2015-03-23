worker = require('pantheon-helpers/lib/worker')
_ = require('underscore')
follow = require('follow')
couch_utils = require('./couch_utils')

handlers = {
}

get_handler_data_path = (doc_type, rsrc) ->
  throw new Error('not implemented')

get_doc_type = (doc) ->
  throw new Error('not implemented')

# _users worker
db = couch_utils.nano_admin.use('db_name')
worker.start_worker(db,
                    handlers,
                    get_handler_data_path,
                    validate._get_doc_type
                   )
