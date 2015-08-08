t = {
  basicAuth: require('basic-auth')
}

module.exports = 

  systemAuth: (conf) ->
    SYSTEM_USER = conf.COUCHDB.SYSTEM_USER
    (req, resp, next) ->
      # look for admin credentials in basic auth, and if valid, login user as admin.
      credentials = t.basicAuth(req)
      if conf.DEV or
         (
          credentials and
          credentials.name == SYSTEM_USER and
          credentials.pass == conf.COUCH_PWD
         )
        req.session or= {}
        req.session.user = SYSTEM_USER
      return next()

  couch: (couchUtils) ->
    (req, resp, next) ->
      # add to the request a couch client tied to the logged in user
      req.couch = couchUtils.nano_user(req.session.user)
      return next()

  ensureAuthenticated: (req, resp, next) ->
    if not req.session?.user
      return resp.status(401).end(JSON.stringify({error: "unauthorized", msg: "You are not logged in."}))
    else
      next()

  testing: t