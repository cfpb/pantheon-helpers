_ = require('underscore')
Promise = require('../promise')

audit = (dbNames, couch_utils) ->
  conf = couch_utils.conf
  audit = {}


  audit.getAudit = (client, startDate, endDate) ->
    # return promise only
    opts = {
      path: '/audit'
      qs: {}
    }

    if startDate? and not isNaN(startDate)
      opts.qs.startkey = startDate
    if endDate? and not isNaN(endDate)
      opts.qs.endkey = endDate

    auditPromises = dbNames.map((db) ->
      db.viewWithList('pantheon', 'audit_by_timestamp', 'get_values', 'promise')
    )

    Promise.all(auditPromises).then((resps) ->
      entries = _.flatten(resps, true)
      entries = _.sortBy(entries, (entry) -> return entry.entry.dt)    
      Promise.resolve(entries)
    )

  audit.handleGetAudit = (req, resp) ->
    startDate = parseInt(req.query.start)
    endDate = parseInt(req.query.end)
    audit.getAudit(req.couch, startDate, endDate).then((entries) ->
      resp.send(JSON.stringify(entries))
    (err) ->
      console.error('handle_get_audit', err)
    ) resp.status(500).send(JSON.stringify({error: 'internal error', msg: 'internal error'}))

  return audit

module.exports = audit
