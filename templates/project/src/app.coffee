pantheonMiddleware = require('pantheon-helpers/lib/middleware')
conf = require('./config')

express = require('express')
bodyParser = require('body-parser')
session = require('cookie-session')
routes = require('./routes')

# create application
app = express()

# parse the body as json ONLY IF mime type
# set to 'application/json'
app.use(bodyParser.json())

# allow system user to login with basic auth
# prohibit everything else
# if conf.DEV == true (for testing), then
# unauthenticated reqs logged in as system user
app.use(pantheonMiddleware.auth(conf))

# attach a nano couch client authenticated as the
# logged-in user to the request object
# access via `req.couch`
app.use(pantheonMiddleware.couch)

# api routes
routes(app)

# start server
server = app.listen(conf.APP?.PORT or 5000, () ->
  host = server.address().address
  port = server.address().port
  console.log('app listening at http://%s:%s', host, port)
)
