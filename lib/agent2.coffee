
'use strict';

bl = require('bl')
util = require('util')
events = require('events')
dgram = require('dgram')
parse = require('coap-packet').parse
generate = require('coap-packet').generate
URL = require('url')
IncomingMessage = require('./incoming_message')
OutgoingMessage = require('./outgoing_message')
ObserveStream = require('./observe_read_stream')
optionsConv = require('./option_converter')
RetrySend = require('./retry_send')
parseBlock2 = require('./helpers').parseBlock2
createBlock2 = require('./helpers').createBlock2
getOption = require('./helpers').getOption
maxToken = Math.pow(2, 32)
maxMessageId = Math.pow(2, 16)
pf = require('./polyfill')

dtlsClient = require('node-mbed-dtls')



class Agent extends events.EventEmitter

  constructor: (opts, dtlsOpts, cb) ->
    @_msgIdToReq = {}
    @_tkToReq = {}
    @_opts=opts
    @_dtlsOpts=dtlsOpts

    @_lastToken = Math.floor(Math.random() * (maxToken - 1))
    @_lastMessageId = Math.floor(Math.random() * (maxMessageId - 1))

    @_closing = false
    @_msgInFlight = 0
    @_requests = 0

    @bigSocket = null

    console.log("These are our DTLS client opts:  ", JSON.stringify(dtlsOpts, 4));

    dtlsOpts.socket = dgram.createSocket({
      type: @_opts.type,
      reuseAddr: true
      })

    @bigSocket = dtlsClient.connect(dtlsOpts, (socket) =>
      socket.on('data', (msg) =>
        console.log("Message: ", msg);
        packet=null
        message=null
        outSocket=null
        try
          packet = parse(msg)
        catch err
          message = generate({
            code: '5.00',
            payload: new Buffer('Unable to parse packet')
          })
          socket.send(message)

        outSocket = {
          port: dtlsOpts.port,
          address: dtlsOpts.host,
          family: @_opts.type == 'udp4' ? 'IPv4' : 'IPv6'
        }
        @_handle(msg, outSocket, socket)
      )
    )

    @bigSocket.on('secureConnect', (socket) =>
      @_sock = socket
      console.log("node-coap: secureConnect: "+util.inspect(socket , 2)+"\n");
      if (cb)
        console.log("Handshake complete.\n");
        cb(this)
    )

    @bigSocket.on('error', (err) =>
      console.log("node-coap: Error: ", err);
      #@emit('error', err);
      @_sock = false
    )

    @bigSocket.on('close', (err) =>
       console.log("node-coap: Closed\n");
      @_sock = false;
    )

  finish: =>
    console.log("CLEANUP")
    for k in @_msgIdToReq
      @_msgIdToReq[k].sender.reset()
    #@_doClose();
    bigSocket.end()

  _cleanUp: =>
    if (@_requests != 0)
      return
    @_closing = true
    if (@_msgInFlight != 0)
      return
    @_doClose()

  _doClose: =>
    for k in @_msgIdToReq
      @_msgIdToReq[k].sender.reset()
    @_sock.close()
    @_sock = null

  _handle: (msg,rsinfo,outSocket) =>
    packet = parse(msg)
    buf = null
    response = null
    req = @_msgIdToReq[packet.messageId]

    ackSent: (err) =>
      if (err and req)
        req.emit('error', err)
      @_msgInFlight--
      if (@_closing and  @_msgInFlight == 0)
        @_doClose()

    if (!req)
      if (packet.token.length == 4)
        req = @_tkToReq[packet.token.readUInt32BE(0)]
      if (packet.ack and !req)
        return
      if (!req)
        buf = generate({
          code: '0.00',
          reset: true,
          messageId: packet.messageId
        })
        @_msgInFlight++;
        @_sock.send(buf, 0, buf.length, rsinfo.port, rsinfo.address, ackSent)
        return


    if (packet.confirmable)
      buf = generate({
        code: '0.00',
        ack: true,
        messageId: packet.messageId
      })
      @_msgInFlight++
      @_sock.send(buf, 0, buf.length, rsinfo.port, rsinfo.address, ackSent)

    if (packet.code != '0.00' && (req._packet.token.length != packet.token.length || pf.compareBuffers(req._packet.token, packet.token) != 0))
      return

    if (!packet.confirmable && !req.multicast)
      delete @_msgIdToReq[packet.messageId]

    req.sender.reset()

    if (packet.code == '0.00')
      return

    block2Buff = getOption(packet.options, 'Block2')
    block2=null
    if (block2Buff)
      block2 = parseBlock2(block2Buff)
      if (!block2)
        req.sender.reset()
        return req.emit('error', new Error('failed to parse block2'))

    if (block2)
      req._totalPayload = Buffer.concat([req._totalPayload, packet.payload])
      if (block2.moreBlock2)
        delete @_msgIdToReq[req._packet.messageId]
        req._packet.messageId = @_nextMessageId()
        @_msgIdToReq[req._packet.messageId] = req
        block2Val = createBlock2({
          moreBlock2: false,
          num: block2.num + 1,
          size: block2.size
        })
        if (!block2Val)
          req.sender.reset()
          return req.emit('error', new Error('failed to create block2'))
        req.setOption('Block2', block2Val)
        req.sender.send(generate(req._packet))
        return
      else
        packet.payload = req._totalPayload
        req._totalPayload = new Buffer(0)


    if (req.response)
      if (req.response.append)
        return req.response.append(packet)
      else
        return
    else if (block2)
      delete @_tkToReq[req._packet.token.readUInt32BE(0)]
    else if (!req.url.observe && packet.token.length > 0)
      delete @_tkToReq[packet.token.readUInt32BE(0)]

    if (req.url.observe && packet.code != '4.04')
      response = new ObserveStream(packet, rsinfo, outSocket)
      response.on('close', val =>
        delete @_tkToReq[packet.token.readUInt32BE(0)]
        @_cleanUp()
      )
    else
      response = new IncomingMessage(packet, rsinfo, outSocket)
    if (!req.multicast)
      req.response = response
    req.emit('response', response)

  _nextToken: =>
    buf = new Buffer(4)
    if (@_lastToken == maxToken)
      @_lastToken = 0
    buf.writeUInt32BE(@_lastToken, 0)
    return buf

  _nextMessageId: =>
    if (@_lastMessageId == maxMessageId)
      @_lastMessageId = 1
    return @_lastMessageId

  request: (url, dtlsOpts) =>
    response=null
    options=url.options || url.headers
    option=null
    multicastTimeout = 20000

    @req = new OutgoingMessage({}, (req, packet) =>
      buf = null

      if (url.confirmable != false)
        packet.confirmable = true

      if (url.multicast == true)
        req.multicast = true
        packet.confirmable = false


      if (!(packet.ack || packet.reset))
        packet.messageId = @_nextMessageId()
        packet.token = @_nextToken()

      try
        buf = generate(packet)
      catch err
        console.log("error1")
        req.sender.reset()
        return req.emit('error', err)

      @_msgIdToReq[packet.messageId] = req
      @_tkToReq[@_lastToken] = req
      req.sender.send(buf)
    )

    @req.sender = new RetrySend(@_sock, url.port, url.hostname || url.host)

    @req.url = url

    @req.statusCode = url.method || 'GET'

    @urlPropertyToPacketOption(url, @req, 'pathname', 'Uri-Path', '/')
    @urlPropertyToPacketOption(url, @req, 'query', 'Uri-Query', '&')

    if (options)
      for option in options
        if (options.hasOwnProperty(option))
          @req.setOption(option, options[option])

    if (url.proxyUri)
      @req.setOption('Proxy-Uri', url.proxyUri)

    @req.sender.on('error', (err) =>
      @req.emit('error', err)
      )

    @req.sender.on('sending', (val) =>
      console.log("sending")
      console.log(val)
      @_msgInFlight++
    )

    @req.sender.on('timeout', (err) =>
      console.log("timeout")
      @req.emit('timeout', err)
      @abort(@req)
    )

    @req.sender.on('sent', () =>
      console.log("sent")
      if (@req.multicast)
        return
      @_msgInFlight--
      if (@_closing and @_msgInFlight == 0)
        @_doClose()
    )

    if (url.multicast == true)
      @req.multicastTimer = setTimeout ->
        @_msgInFlight--
        if (@_msgInFlight == 0)
          @_doClose()
      , multicastTimeout

    if (url.observe)
      @req.setOption('Observe', null)
    else
      @req.on('response', =>
        console.log("responseeer")
        @req.sender.reset()
        @_cleanUp.bind(this)
      )

    @_requests++
    @req._totalPayload = new Buffer(0)
    return @req

  abort: (req) =>
    req.sender.removeAllListeners()
    req.sender.reset()
    @_cleanUp()
    delete @_msgIdToReq[req._packet.messageId]
    delete @_tkToReq[req._packet.token.readUInt32BE(0)]

  urlPropertyToPacketOption: (url, req, property, option, separator) ->
    if (url[property])
      req.setOption(option, url[property].split(separator)
        .filter( (part) ->
          return part != ''
        )
        .map( (part) ->
          buf = new Buffer(Buffer.byteLength(part))
          buf.write(part)
          return buf
        )
      )

module.exports = Agent
