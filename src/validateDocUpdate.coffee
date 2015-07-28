_ = require('underscore')

v =
  validateDocUpdate: (validationFns, getDocType, shouldSkipValidationForUser) ->
    shouldSkipValidationForUser or= () -> false
    return (newDoc, oldDoc, actor) ->
      docType = getDocType(oldDoc or newDoc)
      actions = validationFns[docType]
      newAuditEntries = v.getNewAuditEntries(newDoc, oldDoc)

      if shouldSkipValidationForUser(actor) or
         not actions or
         not newAuditEntries.length
        return

      v.validateAuditEntries(actions, newAuditEntries,
                                      actor, oldDoc, newDoc)

  getNewAuditEntries: (newDoc, oldDoc) ->
    newLog = newDoc.audit or []
    oldLog = if oldDoc then oldDoc.audit else []
    newEntries = newLog.slice(oldLog.length)
    if not newEntries.length
      return newEntries
    oldEntries = newLog.slice(0, oldLog.length)
    if not _.isEqual(oldLog, oldEntries)
      throw({ code: 403, body: 'Entries are immutable. original entries: ' + JSON.stringify(oldLog) + '; modified entries: ' + JSON.stringify(oldEntries) + '.' })
    return newEntries

  validateAuditEntries: (actions, newAuditEntries, actor, oldDoc, newDoc) ->
    newAuditEntries.forEach((entry) -> v.validateAuditEntry(actions, entry, actor, oldDoc, newDoc))

  validateAuditEntry: (actions, entry, actor, oldDoc, newDoc) ->
    if entry.u != actor.name
      throw({ code: 403, body: 'User performing action (' + entry.u + ') does not match logged in user (' + actor.name + ').' })
    if entry.a not of actions
      throw({ code: 403, body: 'Invalid action: ' + entry.a + '.' })

    try
      authorized = actions[entry.a](entry, actor, oldDoc, newDoc) or false
    catch e
      if e.state == 'unauthorized'
        throw({ code: 401, body: e.err })
      else
        throw({ code: 403, body: e.err })      

module.exports = v
