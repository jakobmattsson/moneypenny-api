lockeClient = require 'locke-client-jsonrpc'
jsonrpc = require 'jsonrpc-http-client-node'
manikin = require 'manikin-mongodb'

process.on 'uncaughtException', (ex) ->
  console.log 'Uncaught exception', ex.message
  console.log typeof ex.stack
  console.log ex.stack
  console.log ex
  process.exit 1

locke = lockeClient.construct({
  jsonrpcClient: jsonrpc.construct({ endpoint: 'http://locke.herokuapp.com' })
})

require('./app').run({
  locke
  db: manikin.create()
})
