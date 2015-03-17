try
  _ = require('underscore')
  testing = true
catch err
  _ = require('lib/underscore')

a = {
  views: {},
  lists: {},
  rewrites: {},
}

a.views.audit_by_timestamp = 
  map: (doc) ->
    for entry in doc.audit
      typ = if (doc._id.indexOf('team_') == 0) then 'team' else 'user'
      out = {_id: doc._id, name: doc.name, entry: entry, type: typ}
      emit(entry.dt, out)

a.lists.get_values = (header, req) ->
  out = []
  while(row = getRow())
    val = row.value
    out.push(val)
  return JSON.stringify(out)

a.rewrites.audit = {
  from: "/audit",
  to: "/_list/get_values/audit_by_timestamp",
  query: {},
}

module.exports = a
