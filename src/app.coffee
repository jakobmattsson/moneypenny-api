Q = require 'q'
url = require 'url'
path = require 'path'
http = require 'http'
rester = require 'rester'
nconf = require 'nconf'
_ = require 'underscore'
express = require 'express'
lockeClient = require 'locke-client-jsonrpc'
resterTools = require 'rester-tools'
socketio = require 'socket.io'
async = require 'async'
models = require './models'
custom1 = require './custom1'



# Application entry point
# =============================================================================

exports.run = ({ locke, verbose, db }, settings = {}, callback = ->) ->

  verbose ?= true

  # Reading and echoing the configuration for the application
  configFile = path.resolve(__dirname, '../config/config.json')
  nconf.overrides(settings).env().argv().file({ file: configFile }).defaults
    mongo: 'mongodb://localhost/moneypenny'
    NODE_ENV: 'development'
    PORT: 8075

  if verbose
    console.log "Starting up..."
    console.log "* mongo: " + nconf.get('mongo')
    console.log "* environment: " + nconf.get('NODE_ENV')
    console.log "* port: " + nconf.get('PORT')

  # Setting up the express app
  app = express()
  app.use resterTools.replaceContentTypeMiddleware({ 'text/plain': 'application/json', '': 'application/json' }) # required for XDomainRequest
  app.use resterTools.corsMiddleware()
  app.use express.bodyParser()
  app.use express.methodOverride() # allows PUT (and DELETE) to be performed by posting _method=PUT in the post-body
  app.use express.responseTime()
  app.use resterTools.versionMid path.resolve(__dirname, '../package.json')

  # Setting up the socket.io server
  server = http.createServer(app)
  io = socketio.listen(server, { log: verbose })
  io.configure ->
    io.set("transports", ["xhr-polling"])
    io.set("polling duration", 10)

  # Setting up locke
  lockeAppName = 'moneypenny'

  # Defining where user are stored in the models and how to get them
  userModels = [
    table: 'users'
    usernameProperty: 'email'
    callback: (x) -> { id: x.id }
  ]
  getUserFromDb = resterTools.authUser(
    resterTools.authenticateWithBasicAuthAndLocke(locke, lockeAppName)
    resterTools.getAuthorizationData(db, userModels)
  )

  # Connecting to the database
  Q.ninvoke(db, 'connect', nconf.get('mongo'), models)
  .fail ->
    console.log "ERROR: Could not connect to db"

  # Adding custom routes to the app
  .then ->
    manikinConnectionData = nconf.get('mongo')

    def = (method, path, cb) ->
      app[method] path, (req, res) ->
        cb { req, db: db }, (err, data) ->
          if err?
            if err instanceof Error
              res.json({ err: err.message?.toString() || err.toString() })
            else
              res.json({ err: err })
          else
            res.json(data)

    secure = (f) ->
      (args, callback) ->
        getUserFromDb args.req, (err, usr) ->
          return callback('invalid user') if err?
          db2 = rester.acm.build(args.db, models, usr)
          f(_.extend({}, args, { acdb: db2 }), callback)

    customArgs = {app, db, getUserFromDb, io, models, manikinConnectionData, def, secure}
    [custom1].forEach (custom) ->
      custom.routes(customArgs)

  # Starting up the server
  .then ->
    rester.exec app, db, models, getUserFromDb, { verbose }
    server.listen nconf.get('PORT')
    console.log("Ready!") if verbose
    callback(null, server)
  .done()
