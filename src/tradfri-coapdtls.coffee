###
  Copyright (c) 2017 treban

  tradfri-coapdtls is licensed under an MIT +no-false-attribs license.
  All rights not explicitly granted in the MIT license are reserved.
  See the included LICENSE file for more details.
###

'use strict';

pthrottler = require('p-throttler')

Agent = require('./lib/agent')
parameters = require('./lib/parameters')
net = require('net')
URL = require('url')
util = require('util')
events = require('events')

class TradfriCoapdtls extends events.EventEmitter

  throttler=pthrottler.create(10, {'coap-req': 1})
  @globalAgent = null
  @dtls_opts=null

  tradfriconnector = null
  tradfriIP=null

  coapTiming = {
    ackTimeout:0.5,
    ackRandomFactor: 1.0,
    maxRetransmit: 2,
    maxLatency: 2,
    piggybackReplyMs: 10,
    debug: 0
  }

  constructor: (config) ->

    tradfriIP = config.hubIpAddress
    parameters.refreshTiming(coapTiming)

    @dtls_opts = {
      host:           tradfriIP,
      port:           5684,
      psk:            new Buffer(config.securityId),
      PSKIdent:       new Buffer(config.clientId),
      peerPublicKey:  null,
      key:            null
    }

  connect: =>
    return new Promise((resolve, reject) =>
      @globalAgent=new Agent({
        type: 'udp4',
        host: tradfriIP,
        port: 5684
      },@dtls_opts, (res) =>
        return resolve()
      )
    )

  finish: ->
    @globalAgent.finish()
    throttler.abort()
    throttler=pthrottler.create(10, {'coap-req': 1})

  initPSK: (ident) ->
    payload = {
      9090 : ident
    }
    return @_send_request('/15011/9063',payload,false,true)

  getGatewayInfo: ->
    return @_send_request('/15011/15012')

  setGateway: (pay) ->
    payload = {
      9023 : pay
    }
    return @_send_request('/15011/15012',payload)

  getAllDevices: ->
    promarr=[]
    @getAllDeviceIDs().then( (ids)=>
      ids.forEach((id) =>
        promarr.push(@getDevicebyID(id))
      )
      return Promise.all(promarr)
    ).catch ( (err) =>
      reject(err)
    )

  getAllGroups: ->
    promarr2=[]
    @getAllGroupIDs().then( (ids)=>
      ids.forEach((id) =>
        promarr2.push(@getGroupbyID(id))
      )
      return Promise.all(promarr2)
    ).catch ( (err) =>
      reject(err)
    )

  getAllScenes: (gid) ->
    promarr3=[]
    @getAllScenesIDs(gid).then( (ids)=>
      ids.forEach((id) =>
        promarr3.push(@getScenebyID(gid,id))
      )
      return Promise.all(promarr3)
    ).catch ( (err) =>
      reject(err)
    )

  getAllDeviceIDs: ->
    return @_send_request('/15001')

  getAllGroupIDs: ->
    return @_send_request('/15004')

  getAllScenesIDs: (gid) ->
    return @_send_request('/15005'+gid)

  getDevicebyID: (id) ->
    return @_send_request('/15001/'+id)

  getGroupbyID: (id) ->
    return @_send_request('/15004/'+id)

  getScenebyID: (gid,id) ->
    return @_send_request('/15005/'+gid+'/'+id)

  setDevice: (id,sw,time=5) ->
    payload = {
      3311 : [{
        5850 : sw.state,
        5712 : time
        }]
    }
    if ( sw.brightness > 0 )
      payload[3311][0][5851] = sw.brightness
    return @_send_request('/15001/'+id,payload)

  setGroup: (id,sw,time=5) ->
    payload = {
      5850 : sw.state,
      5712 : time
    }
    if ( sw.brightness > 0 )
      payload[5851] = sw.brightness
    return @_send_request('/15004/'+id,payload)

  setColorHex: (id,color,time=5) ->
    payload = {
      3311 : [{
        5706 : color,
        5712 : time
        }]
    }
    return @_send_request('/15001/'+id,payload)

  setColorXY: (id,colorX,colorY,time=5) ->
    payload = {
      3311 : [{
        5709 : colorX,
        5710 : colorY,
        5712 : time
        }]
    }
    return @_send_request('/15001/'+id,payload)

  setColorTemp: (id,color,time=5) ->
    payload = {
      3311 : [{
        5709 : color,
        5710 : 27000,
        5712 : time
        }]
    }
    return @_send_request('/15001/'+id,payload)


  setScene: (gid,id) ->
    payload = {
      5850 : 1
      9039 : id
    }
    return @_send_request('/15004/'+gid,payload)

  setObserver: (id,callback) =>
    return @_send_request('/15001/'+id,false,callback)

  setObserverGroup: (id,callback) =>
    return @_send_request('/15004/'+id,false,callback)

  _send_request: (command, payload,callback,ident) =>
    #console.log("Send #{command}")
    throttler.enqueue( (bla) =>
       return @_send_command(command,payload,callback,ident)
    , 'coap-req')

  _send_command: (command,payload,callback,ident) =>
    @req=null
    return new Promise((resolve, reject) =>
      url = {
        protocol: "coaps:",
        slashes: true,
        auth: null,
        host: tradfriIP+":5684",
        port: "5684",
        hostname: tradfriIP,
        hash: null,
        search: null,
        query: null,
        method: "GET",
        pathname: command
        path: command
        href: "coaps://"+tradfriIP+":5684"+command
      }
      if (payload)
        if (ident)
          url["method"]="POST"
        else
          url["method"]="PUT"
      else
        url["method"]="GET"
      if (callback)
        url["observe"]=true

  #    console.log(url)
  #    console.log(payload)
      @req = @globalAgent.request(url, @dtlsOpts)

      @req.on('error', (error) =>
        reject(error)
      )

      if (payload)
        @req.write(JSON.stringify(payload))

      @req.on('response', (res) =>
  #      console.log("Respone Code")
  #      console.log(res.code)
        if (res.code == '4.04' or res.code == '4.05' )
          reject(res.code)
        else
          if (callback)
            res.on('data', (dat) =>
              callback(JSON.parse(dat.toString()))
            )
            resolve("RC : "+res.code)
          if (!payload)
  #          console.log(res)
            resolve(JSON.parse(res.payload.toString()))
          else
  #          console.log(res)
            if (ident)
              resolve(JSON.parse(res.payload.toString()))
            else
              resolve("RC: "+res._packet.code)
      )
      @req.end()
    )

module.exports = TradfriCoapdtls
