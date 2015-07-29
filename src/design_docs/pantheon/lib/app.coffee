_ = require('underscore')

sendNakedList = (getRow, start, send, rowTransform) ->
  ###
  lazily send a JSON serialized list of rows,
  each having been transformed by rowTransform.
  If rowTransform throws the string `"skip"`,
  the row will be skipped.

  coppied from pantheon-helpers-design-docs.helpers
  b/c npm does not preserve symlinks
  ###
  start({
    headers: {
      'Content-Type': 'application/json'
    }
  })
  first = true
  send('[')
  while(row = getRow())
    try
      transformedRow = rowTransform(row)
    catch e
      if e == 'skip'
        continue
      else
        throw e

    if first
      first = false
    else
      send(',')

    send(JSON.stringify(transformedRow))
  send(']')


dd =
  views:
    failures_by_retry_date:
      map: (doc) ->
        now = +new Date()
        nextAttemptTime = 1e+100
        for entry in (doc.audit or [])
          if entry.attempts?[0] < nextAttemptTime
            nextAttemptTime = entry.attempts?[0]
        if nextAttemptTime < 1e+100
            emit(nextAttemptTime)
    audit_by_timestamp:
      map: (doc) ->
        for entry in doc.audit
          typ = if (doc._id.indexOf('team_') == 0) then 'team' else 'user'
          out = {_id: doc._id, name: doc.name, entry: entry, type: typ}
          emit(entry.dt, out)

  lists:
    get_values: (header, req) ->
      sendNakedList(getRow, start, send, (row) -> row.value)

  rewrites: [
    {
      from: "/audit",
      to: "/_list/get_values/audit_by_timestamp",
      query: {},
    }
  ]

  shows: {}

  updates: {}

if typeof(emit) == 'undefined'
  dd.emitted = []
  emit = (k, v) -> dd.emitted.push([k, v])

module.exports = dd
