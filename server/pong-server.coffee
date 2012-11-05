http = require 'http'
sockjs = require 'sockjs'
_ = require 'underscore'

pongGame = require '../common/game'
config = require '../common/config'
utils = require '../common/utils'
message = require '../common/message'

PongGame = pongGame.WebPongJSGame
Message = message.WebPongJSMessage

class PongServer
  @NEEDED_PLAYERS: 2

  constructor: ->
    @config = config.WebPongJSConfig
    @players = {}
    @httpServer = http.createServer()
    @sockServer = sockjs.createServer()
    try
      @game = new PongGame @config
    catch e
      console.error "Could not create new game using configuration #{@config}"
      throw e
    @handlers =
      init: this.onInit,
      update: this.onUpdate,
      moveUp: this.onMoveUp,
      moveDown: this.onMoveDown
    @updaterId = null

  listen: ->
    @sockServer.installHandlers @httpServer,
      prefix: @config.server.prefix
    @sockServer.on 'connection', this.onConnection
    @httpServer.on 'error', (e) =>
      console.error "Error running http server on #{@config.server.addr}:#{@config.server.port} #{e}"
    @httpServer.listen @config.server.port, @config.server.addr

  # SockJS connection handlers
  onConnection: (conn) =>
    if this.playerCount() >= @NEEDED_PLAYERS
      this.send conn, 'close', 'Cannot join. Game is full'
      conn.close()
    else
      conn.on 'data', this.onData conn
      conn.on 'close', this.onClose conn
      this.addPlayer conn
      if this.playerCount() == @NEEDED_PLAYERS
        console.log 'Got 2 players. Starting game'
        this.send conn, 'start', null
        this.setupUpdater()
        @game.start()

  onData: (conn) =>
    (msg) =>
      console.log "Got message #{msg} from #{conn.id}"
      msg = Message.parse msg
      handler = @handlers[msg.type]
      if handler?
        handler conn, msg.data

  onClose: (conn) =>
    =>
      console.log "Connection #{conn.id} closed"
      this.removePlayer conn
      this.stopUpdater()
      @game.stop()
      this.broadcast 'drop', null
      console.log "Game stopped, due to player connection #{conn.id} drop"

  # Message handlers
  onInit: (conn, data) =>
    block = @players[conn.id].block
    this.send conn, 'init',
      timestamp: (new Date).getTime(),
      block: block

  onUpdate: (conn, data) =>
    this.send conn 'update', @game.state

  onMoveUp: (conn, data) =>
    @game.state.blocks[@players[conn.id].block].moveUp()
    this.broadcast 'update', @game.state

  onMoveDown: (conn, data) =>
    @game.state.blocks[@players[conn.id].block].moveDown()
    this.broadcast 'update', @game.state

  # Connection helper methods
  send: (conn, msgType, msgData) =>
    try
      msg = (new Message msgType, msgData).stringify()
    catch e
      console.error "Could not serialize message: type:#{msgType}, data:#{msgData} for sending to #{conn}"
    try
      conn.write msg
    catch e
      console.error "Could not send message #{msg} to #{conn}: #{e}"

  broadcast: (type, msg) ->
    for cid, p of @players
      this.send p.connection, type, msg

  broadcastState: =>
    this.broadcast 'update', @game.state

  # Player management methods
  addPlayer: (conn) ->
    @players[conn.id] =
      connection: conn,
      block: ['left', 'right'][this.playerCount()]

  removePlayer: (conn) ->
    delete @players[conn.id]

  playerCount: ->
    _.keys(@players).length

  # Periodic client updates
  setupUpdater: ->
    if !@updaterId is null
      @updaterId = setInterval this.broadcastState,
        @config.update.syncTime

  stopUpdater: ->
    if @updaterId?
      clearInterval @updaterId
      @updaterId = null

main = ->
  console.log 'Starting Pong Server'
  pongServer = new PongServer
  pongServer.listen()

main()
