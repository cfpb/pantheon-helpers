try
  _ = require('underscore')
  testing = true
catch err
  _ = require('lib/underscore')

module.exports = (action_handlers, get_doc_type, prep_doc) ->
  (doc, req) ->
    if not doc
      return [null, '{"status": "error", "msg": "doc not found"}']

    action = JSON.parse(req.body)
    action_name = action.a
    actor = req.userCtx
    doc_type = get_doc_type(doc)

    action_handler = action_handlers[doc_type]?[action_name]

    if not action_handler
      return [null, '{"status": "error", "msg": "invalid action"}']

    old_doc = JSON.parse(JSON.stringify(doc)) # clone original to check if change

    try
      action_handler(doc, action, actor)
    catch e
      return [null, JSON.stringify({"status": "error", "msg": e})]

    if _.isEqual(old_doc, doc)
      write_doc = null
    else
      _.extend(action, {
        u: actor.name,
        dt: +new Date(),
      })
      doc.audit.push(action)
      write_doc = doc
    out_doc = if prep_doc then prep_doc(doc) else doc
    return [write_doc, JSON.stringify(out_doc)]
