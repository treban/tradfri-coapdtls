###
  Copyright (c) 2017 treban

  tradfri-coapdtls is licensed under an MIT +no-false-attribs license.
  All rights not explicitly granted in the MIT license are reserved.
  See the included LICENSE file for more details.
###

'use strict';

throttler = require('p-throttler')

Agent = require('./lib/agent')
parameters = require('./lib/parameters')
net = require('net')
URL = require('url')
util = require('util')

class TradfriCoapdtls

  throttler=throttler.create(10, {'coap-req': 1})
  @globalAgent = null
  @dtls_opts=null

  tradfriconnector = null
  tradfriIP=null

  coapTiming = {
    ackTimeout:1.5,
    ackRandomFactor: 3.0,
    maxRetransmit: 3,
    maxLatency: 5,
    piggybackReplyMs: 40
  }

  constructor: (config , cb) ->

    tradfriIP = config.hubIpAddress
    parameters.refreshTiming(coapTiming)

    @dtls_opts = {
      host:           tradfriIP,
      port:           5684,
      psk:            new Buffer(config.securityId),
      PSKIdent:       new Buffer('Client_identity'),
      peerPublicKey:  null,
      key:            null
    }

    @globalAgent=new Agent({
      type: 'udp4',
      host: tradfriIP,
      port: 5684
    },@dtls_opts,cb)

  getGatewayInfo: ->
    return @_send_request('/15011/15012')

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

  getAllDeviceIDs: ->
    return @_send_request('/15001')

  getAllGroupIDs: ->
    return @_send_request('/15004')

  getDevicebyID: (id) ->
    return @_send_request('/15001/'+id)

  getGroupbyID: (id) ->
    return @_send_request('/15004/'+id)

  setDevice: (id,sw) ->
    payload = {
      3311 : [{
        5850 : sw.state,
        5851 : sw.brightness
        }]
    }
    return @_send_request('/15001/'+id,payload)

  setGroup: (id,sw) ->
    payload = {
      5850 : sw.state
    }
    return @_send_request('/15004/'+id,payload)

  setColorHex: (id,color) ->
    payload = {
      3311 : [{
        5706 : color
        }]
    }
    return @_send_request('/15001/'+id,payload)

  setObserver: (id,callback) =>
    return @_send_request('/15001/'+id,false,callback)

  setObserverGroup: (id,callback) =>
    return @_send_request('/15004/'+id,false,callback)

  _send_request: (command, payload,callback) =>
    throttler.enqueue( (bla) =>
       return @_send_command(command,payload,callback)
    , 'coap-req')

  _send_command: (command,payload,callback) =>
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
        url["method"]="PUT"
      else
        url["method"]="GET"
      if (callback)
        url["observe"]=true

      #console.log(url)
      #console.log(payload)
      @req = @globalAgent.request(url, @dtlsOpts)

      @req.on('error', (error) =>
        reject(error)
      )

      if (payload)
        @req.write(JSON.stringify(payload))

      @req.on('response', (res) =>
      #  console.log("Respone Code")
      #  console.log(res.code)
        if (res.code == '4.04')
          reject("RC: "+res.code+" URL: "+ JSON.stringify(url))
        else
          if (callback)
            res.on('data', (dat) =>
              callback(JSON.parse(dat.toString()))
            )
            resolve("RC : "+res.code)
          if (!payload)
          #  console.log(res)
            resolve(JSON.parse(res.payload.toString()))
          else
          #  console.log(res)
            resolve("Response Code: "+res._packet.code)
      )
      @req.end()
    )

module.exports = TradfriCoapdtls
