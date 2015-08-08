_ = require('underscore')
uuid = require('node-uuid')
Promise = require('./promise')
a = {}
validate = require('./validateDocUpdate')
utils = require('./utils')

deepSimpleClone = (obj) ->
  return JSON.parse(JSON.stringify(obj))


a.getDoc = (client, dbName, docId) ->
  ### returns promise ###
  if _.isObject(docId) # if a doc object was passed instead of a doc id, 
    return Promise.resolve(docId)
  else if docId
    return client.use(dbName).get(docId, 'promise')
  else
    return client.getUuid().then((uuid) ->
      Promise.resolve({_id: uuid, audit: []})
    )

a.getActionHandler = (actionHandlers, getDocType) ->
  return (doc, action) ->
    actionName = action.a
    isNewDoc = not doc._rev
    docType = if isNewDoc then 'create' else getDocType(doc)

    actionHandler = actionHandlers[docType]?[actionName]

    if not actionHandler
      errorMsg = 'invalid action "' + actionName + '" for doc type "' + docType + '".'
      throw({code: 403, body: {"status": "error", "msg": errorMsg}})

    return actionHandler

a.runHandler = (actionHandler, doc, action, actor) ->
  try
    actionHandler(doc, action, actor)
  catch e
    throw({code: 500, body: {"status": "error", "msg": e}})

a.doAction = (dbName, couchUtils, actionHandlers, validationFns, getDocType, prepDoc, shouldSkipValidationForUser) ->
  validateDocUpdate = validate.validateDocUpdate(validationFns, getDocType, shouldSkipValidationForUser)
  getActionHandler = a.getActionHandler(actionHandlers, getDocType)
  doAction = (dbName, actorName, docId, action) ->
    ###
    return a doAction method to perform actions of documents in databases
    returned doAction function returns a promise.
    args:
      client: configuration object
      dbName: name of the db in which to perform action
      actionHandlers: 
      getDocType:
      validateDocUpdate:
      prepDoc:
    returned doAction method args:
      dbName: (only if dbName above is undefined)
      actorName: name (or user object) of the user performing the action
      docId: docId (or document object) of the document on which to perform action
      action: action object describing the action
    ###
    oldAction = deepSimpleClone(action)
    _.defaults(action, {id: uuid.v4()})

    client = couchUtils.nano_user(actorName.name or actorName)

    actorPromise = utils.getActor(couchUtils, actorName)
    docPromise = a.getDoc(client, dbName, docId)

    Promise.all([actorPromise, docPromise]).then(([actor, doc]) ->
      oldDoc = deepSimpleClone(doc)

      actionHandler = getActionHandler(doc, action)

      a.runHandler(actionHandler, doc, action, actor)

      if _.isEqual(oldDoc, doc)
        return Promise.resolve([actor, doc])

      validateDocUpdate(doc, oldDoc, actor)

      _.extend(action, {
        u: actor.name,
        dt: +new Date(),
      })
      doc.audit.push(action)

      client.use(dbName).insert(doc, 'promise').catch((err) ->
        if err.statusCode == 409 and docId?
          originalId = docId?._id or docId
          return doAction(dbName, actorName, originalId, oldAction)
        else
          return Promise.reject(err)
      ).then(() -> Promise.resolve([actor, doc]))
    ).then(([actor, doc]) ->
      outDoc = if prepDoc then prepDoc(doc, actor) else doc
      return Promise.resolve(outDoc)
    )

  if dbName?
    return (actorName, docId, action) ->
      return doAction(dbName, actorName, docId, action)
  else
    return doAction

module.exports = a
