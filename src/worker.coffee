_ = require('underscore')
follow = require('follow')
utils = require('./utils')
Promise = require('promise')

x = {}

x.get_handlers = (handlers, entry, doc_type) ->
  ###
  return a hash of {null: handler}, where handler is the handler
  for the entry/doc type combo.

  you can subclass this function to return an arbitrary 
  number of key/handler names. (see, e.g., get_resource_handlers)
  ###
  handler = handlers[doc_type]?[entry.a]
  if handler
    return {null: handler}
  else
    return {}

x.get_plugin_handlers = (handlers, entry, doc_type) ->
  ###
  return a hash of {resource: handler} for each resource that
  has specified a handler for this entry's action.
  ###
  filtered_handlers = {}
  for plugin, plugin_handlers of handlers
    handler = plugin_handlers[doc_type]?[entry.a]
    if not handler
      if entry.k == plugin
        handler = plugin_handlers[doc_type]?.self?[entry.a]
      else
        handler = plugin_handlers[doc_type]?.other?[entry.a]
    if handler
      filtered_handlers[plugin] = handler
  return filtered_handlers


x.get_unsynced_audit_entries = (doc) ->
  return _.filter(doc.audit, (entry) -> return not entry.synced)


x.update_audit_entry_resource = (doc, doc_type, get_handler_data_path) ->
  (result, rsrc) ->
    if result.value?
      data_path = get_handler_data_path(doc_type, rsrc)
      old_data = utils.mk_objs(doc, data_path, {})
      _.extend(old_data, result.value)


x.update_audit_entry = (doc, doc_type, get_handler_data_path) ->
  (entry_results, entry_id) ->
    entry = _.findWhere(doc.audit, {id: entry_id})
    synced = _.all(entry_results, (result) -> result.state == 'resolved')
    entry.synced = entry.synced or synced
    _.each(entry_results, x.update_audit_entry_resource(doc, doc_type, get_handler_data_path))


x.update_audit_entries = (db, doc_id, doc_type, results, get_handler_data_path) ->
  get_doc = Promise.denodeify(db.get).bind(db)
  insert_doc = Promise.denodeify(db.insert).bind(db)
  get_doc(doc_id).then((doc) ->
    old_doc = JSON.parse(JSON.stringify(doc))
    _.each(results, x.update_audit_entry(doc, doc_type, get_handler_data_path))

    if _.isEqual(old_doc, doc)
      return Promise.resolve()
    else
      insert_doc(doc).catch((err) ->
        if err.status_code == 409
          return x.update_audit_entries(db, doc_id, doc_type, results, get_handler_data_path)
        else
          Promise.reject(err)
      )
  )


x.on_change = (db, handlers, get_handler_data_path, get_doc_type, get_handlers=x.get_handlers) ->
  return (change) ->
    doc = change.doc
    doc_type = get_doc_type(doc)
    unsynced_audit_entries = x.get_unsynced_audit_entries(doc)

    entry_promises = {}
    _.each(unsynced_audit_entries, (entry) ->
      entry_handlers = get_handlers(handlers, entry, doc_type)
      handler_promises = {}
      _.each(entry_handlers, (handler, rsrc) -> handler_promises[rsrc] = handler(entry, doc))
      entry_promises[entry.id] = Promise.hashResolveAll(handler_promises)
    )
    Promise.hashAll(entry_promises).then((results) ->
      # results is a hash of type:
      # {entry_id: {resource: {state: "resolved|rejected", value|error: "result"}}}
      x.update_audit_entries(db, doc._id, doc_type, results, get_handler_data_path)
    ).catch((err) ->
      console.log('ERR', err)
    )


x.start_worker = (db, handlers, get_handler_data_path, get_doc_type) ->
  ###
  start a worker that watches a db for changes and calls the appropriate handlers.
  db: the nano database to watch
  handlers: a hash of handlers. Each handler should handle a different action.
  get_handler_data_path: a function that return a path array into the document where data returned by the handler should be stored.
  get_doc_type: a function that returns the document type. this can be used to look up the appropriate handler.
  ###
  opts = 
    db: db.config.url + '/' + db.config.db
    include_docs: true

  feed = new follow.Feed(opts);

  feed.filter = (doc, req) ->
    if doc._deleted
      return false
    else
      return true

  feed.on 'change', x.on_change(db, handlers, get_handler_data_path, get_doc_type)

  feed.on 'error', (err) ->
    console.log(err)

  feed.follow()
  return feed


module.exports = x
