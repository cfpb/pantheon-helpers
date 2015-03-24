_ = require('./underscore')
actions = require('./actions')
audit = require('./shared/audit')

dd =
  views: {}

  lists: {}

  shows: {}

  updates: {}

  rewrites: []

audit.mixin(dd)
actions.mixin(dd)

module.exports = dd
