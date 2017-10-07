/*
 * Copyright (c) 2017 treban, dlemper
 *
 * tradfri-coapdtls is licensed under an MIT +no-false-attribs license.
 * All rights not explicitly granted in the MIT license are reserved.
 * See the included LICENSE file for more details.
 */

'use strict';

const pthrottler = require('p-throttler')

const Agent = require('./lib/agent')
const parameters = require('./lib/parameters')
const net = require('net')
const URL = require('url')
const util = require('util')
const events = require('events')

const throttler = pthrottler.create(10, { 'coap-req': 1 });

const coapTiming = {
  ackTimeout: 0.5,
  ackRandomFactor: 1.0,
  maxRetransmit: 2,
  maxLatency: 2,
  piggybackReplyMs: 10,
  debug: 0,
};

class TradfriCoapdtls extends events.EventEmitter {
  constructor (config) {
    super();

    this.globalAgent = null;
    this.dtls_opts = null;

    this.tradfriIP = config.hubIpAddress
    parameters.refreshTiming(coapTiming);

    this.dtls_opts = {
      host: this.tradfriIP,
      port: 5684,
      psk: new Buffer(config.securityId),
      PSKIdent: new Buffer('Client_identity'),
      peerPublicKey: null,
      key: null,
    };
  }

  connect() {
    return new Promise((resolve, reject) => {
      this.globalAgent = new Agent({
        type: 'udp4',
        host: this.tradfriIP,
        port: 5684,
      }, this.dtls_opts, (res) => {
        return resolve();
      });
    });
  }

  finish() {
    this.globalAgent.finish();
    throttler.abort();
    throttler = pthrottler.create(10, { 'coap-req': 1 });
  }

  getGatewayInfo() {
    return this._send_request('/15011/15012');
  }

  setGateway(payload) {
    return this._send_request('/15011/15012', { 9023: payload });
  }

  getAllDevices() {
    return this.getAllDeviceIDs()
      .then(ids => Promise.all(ids.map(id => this.getDevicebyID(id))));
  }

  getAllGroups() {
    return this.getAllGroupIDs()
      .then(ids => Promise.all(ids.map(id => this.getGroupbyID(id))));
  }

  getAllScenes(gid) {
    return this.getAllScenesIDs(gid)
      .then(ids => Promise.all(ids.map(id => this.getScenebyID(gid,id))));
  }

  getAllDeviceIDs() {
    return this._send_request('/15001');
  }

  getAllGroupIDs() {
    return this._send_request('/15004');
  }

  getAllScenesIDs(gid) {
    return this._send_request(`/15005${gid}`);
  }

  getDevicebyID(id) {
    return this._send_request(`/15001/${id}`);
  }

  getGroupbyID(id) {
    return this._send_request(`/15004/${id}`);
  }

  getScenebyID(gid, id) {
    return this._send_request(`/15005/${gid}/${id}`);
  }

  setDevice(id, sw, time = 5) {
    return this._send_request(`/15001/${id}`, {
      3311: [{
        5850: sw.state,
        5712: time,
        0: sw.brightness > 0 ? { 5851: sw.brightness } : undefined,
      }],
    });
  }

  setGroup(id,sw,time = 5) {
    return this._send_request(`/15004/${id}`, {
      5850: sw.state,
      5712: time,
    });
  }

  setColorHex(id, color, time = 5) {
    return this._send_request(`/15001/${id}`, {
      3311: [{
        5706: color,
        5712: time,
      }],
    });
  }

  setColorXY(id, color, time = 5) {
    return this._send_request(`/15001/${id}`, {
      3311: [{
        5709: color,
        5710: 27000,
        5712: time,
      }],
    });
  }

  setScene(gid, id) {
    return this._send_request(`/15004/${gid}`, {
      5850: 1,
      9039: id,
    });
  }

  setObserver(id, callback) {
    return this._send_request(`/15001/${id}`, false, callback);
  }

  setObserverGroup(id, callback) {
    return this._send_request(`/15004/${id}`, false, callback);
  }

  _send_request(command, payload, callback) {
    // console.log("Send #{command}")
    return throttler.enqueue(() => this._send_command(command, payload, callback), 'coap-req');
  }

  _send_command(command, payload, callback) {
    this.req = null;
    return new Promise((resolve, reject) => {
      const url = {
        protocol: 'coaps:',
        slashes: true,
        auth: null,
        host: `${this.tradfriIP}:5684`,
        port: '5684',
        hostname: this.tradfriIP,
        hash: null,
        search: null,
        query: null,
        method: 'GET',
        pathname: command,
        path: command,
        href: `coaps://${this.tradfriIP}:5684${command}`,
      };

      if (payload) {
        url['method'] = 'PUT';
      } else {
        url['method'] = 'GET';
      }

      if (callback) {
        url['observe'] = true;
      }

      // console.log(url)
      // console.log(payload)
      this.req = this.globalAgent.request(url, this.dtlsOpts);

      this.req.on('error', reject);

      if (payload) {
        this.req.write(JSON.stringify(payload));
      }

      this.req.on('response', (res) => {
        // console.log("Respone Code")
        // console.log(res.code)
        if (res.code === '4.04' || res.code === '4.05') {
          reject(res.code);
        } else {
          if (callback) {
            res.on('data', dat => callback(JSON.parse(dat.toString())));
            resolve(`RC: ${res.code}`);
          }

          if (!payload) {
            // console.log(res)
            resolve(JSON.parse(res.payload.toString()));
          } else {
            // console.log(res)
            resolve(`RC: ${res._packet.code}`);
          }
        }
      });

      this.req.end();
    });
  }
}

module.exports = TradfriCoapdtls;
