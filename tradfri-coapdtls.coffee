###
  Copyright (c) 2017 treban

  tradfri-coapdtls is licensed under an MIT +no-false-attribs license.
  All rights not explicitly granted in the MIT license are reserved.
  See the included LICENSE file for more details.
###

'use strict';

coapdtls = require('./lib/../coapdtls.js')
throttler = require('p-throttler')

class TradfriCoapdtls

  tradfriconnector = null
  tradfriIP=null
  dtls_opts=null
  throttler=throttler.create(15, {'makeRequest': 1})

  dtls_opts = {
    psk:           new Buffer(''),
    PSKIdent:      new Buffer('Client_identity'),
    peerPublicKey: null,
    key:           null,
  }

  coapTiming = {
    ackTimeout:0.50,
    ackRandomFactor: 1.0,
    maxRetransmit: 5,
    maxLatency: 5,
    piggybackReplyMs: 10
  }

  constructor: (config) ->
    dtls_opts.psk = new Buffer(config.securityId)
    tradfriIP = config.hubIpAddress
    coapdtls.updateTiming(coapTiming);

  getAllDeviceIDs: ->
    @_send_request('/15001').then ( (result) ->
      return result
    )

  getAllGoupsIDs: ->
    @_send_request('/15004').then ( (result) ->
      return result
    )

  getDevicebyID: (id) ->
    @_send_request('/15001/'+id).then ( (result) ->
      return result
    )

  setDevice: (id,sw) ->
    payload = {
      3311 : [{
        5850 : sw.state,
        5851 : sw.brightness
        }]
    }
    @_send_request('/15001/'+id,payload).then ( (result) ->
      return result
    )

  _send_request: (command, payload) ->
    throttler.enqueue( (bla) =>
       @_send_command(command,payload).then ( (result) ->
         return result)
    , 'makeRequest')

  _send_command: (command,payload) ->
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
        method: "GET"
      }
      if (payload)
        url["method"]="PUT"
      else
        url["method"]="GET"
      url.pathname=command
      url.path=command
      url.href="coaps://"+tradfriIP+":5684"+command
      console.log(url)
      console.log(payload)
      req = coapdtls.request(url,
        dtls_opts,
        (req) ->
          req.on('response', (res) ->
            if (!payload)
              resolve(JSON.parse(res.payload.toString()))
            else
              resolve("Response Code: "+res._packet.code)
          )
          req.end()
        ,payload
      )
    )

module.exports = TradfriCoapdtls
