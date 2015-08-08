deepExtend = require('pantheon-helpers').utils.deepExtend
path = require('path')

try
    config_secret = require('./config_secret')
catch e
    config_secret = {}

config = 
  COUCHDB:
    HOST: 'localhost'
    PORT: 5984
    HTTPS: false
    SYSTEM_USER: 'the username used by your microservice to access CouchDB'
  APP:
    PORT: 5000
  LOGGERS:
    WEB:
      streams: [{
        stream: process.stderr,
        level: "error"
      },
      {
        stream: process.stdout,
        level: "info"
      }]
    WORKER:
      streams: [{
        stream: process.stderr,
        level: "error"
      },
      {
        stream: process.stdout,
        level: "info"
      }]
  COUCH_DESIGN_DOCS_DIR: path.join(__dirname, '/design_docs')

deepExtend(config, config_secret)

module.exports = config
