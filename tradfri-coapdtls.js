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

var throttler = pthrottler.create(10, { 'coap-req': 1 });

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
    this.dtlsOpts = null;

    this.config = config;
    this.tradfriIP = config.hubIpAddress

    parameters.refreshTiming(coapTiming);

    this.dtlsOpts = {
      host: this.config.hubIpAddress,
      port: 5684,
      psk: new Buffer(this.config.psk || this.config.securityId),
      PSKIdent: new Buffer(this.config.psk ? this.config.clientId : 'Client_identity'),
      peerPublicKey: null,
      key: null,
    };
  }

  connect() {
    return new Promise((resolve, reject) => {
      this.globalAgent = new Agent({
        type: 'udp4',
        host: this.config.hubIpAddress,
        port: 5684,
      }, this.dtlsOpts, res => {
        if (this.config.psk) {
          console.log("bla")
          resolve();
        } else {
          console.log("initpsk")
          this._initPSK(this.config.clientId).then((data) => {
            console.log("return")
            this.dtlsOpts.PSKIdent = new Buffer(this.config.clientId);
            this.dtlsOpts.psk = new Buffer(data['9091']);
            this.dtlsOpts.socket = null;
            this.config.psk = data['9091'];
            this.globalAgent.finish();
            this.connect().then( (data) => {
                resolve(this.config.psk);
            });
          }).catch( (response) => {
            console.log(response)
          });
        }
      });
    });
  }

  finish() {
    this.globalAgent.finish();
    throttler.abort();
    throttler = pthrottler.create(10, { 'coap-req': 1 });
  }

  _initPSK(ident) {
    console.log(ident)
    return this._send_request('POST','/15011/9063', {9090: ident}, false);
  }

  getGatewayInfo() {
    return this._send_request('GET','/15011/15012');
  }

  setGatewayNTP(ntpserver) {
    return this._send_request('GET','/15011/15012', { 9023: ntpserver });
  }

  setReboot() {
    return this._send_request('POST','/15011/9030');
  }

  setDiscovery() {
    return this._send_request('PUT',`/15011/15012`, { 9061: 30 });
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
    return this._send_request('GET','/15001');
  }

  getAllGroupIDs() {
    return this._send_request('GET','/15004');
  }

  getAllScenesIDs(gid) {
    return this._send_request('GET',`/15005/${gid}`);
  }

  getDevicebyID(id) {
    return this._send_request('GET',`/15001/${id}`);
  }

  getGroupbyID(id) {
    return this._send_request('GET',`/15004/${id}`);
  }

  getScenebyID(gid, id) {
    return this._send_request('GET',`/15005/${gid}/${id}`);
  }

  setDevice(id, sw, time) {
    return this._send_request('PUT',`/15001/${id}`, {
      3311: [{
        5850: sw.state,
        5712: time ? time : 5,
        5851: sw.brightness > 0 ? sw.brightness : undefined,
      }],
    });
  }

  setGroup(id, sw, time) {
    return this._send_request('PUT',`/15004/${id}`, {
      5850: sw.state,
      5712: time ? time : 5,
      5851: sw.brightness > 0 ? sw.brightness : undefined,
    });
  }

  setColorHex(id, color,time) {
    return this._send_request('PUT',`/15001/${id}`, {
      3311: [{
        5706: color,
        5712: time ? time : 5,
      }],
    });
  }

  setColorXY(id, colorX, colorY, time) {
    return this._send_request('PUT',`/15001/${id}`, {
      3311: [{
        5709: colorX,
        5710: colorY,
        5712: time ? time : 5,
      }]
    });
  }

  setColorTemp(id,color, time) {
    return this._send_request('PUT',`/15001/${id}`, {
      3311: [{
        5709: color,
        5710: 27000,
        5712: time ? time : 5,
      }],
    });
  }

  setScene(gid, id) {
    return this._send_request('PUT',`/15004/${gid}`, {
      5850: 1,
      9039: id,
    });
  }

  setSmartSwitch(id, sw) {
    return this._send_request('PUT',`/15001/${id}`, {
      3312: [{
        5850: sw.state
      }]
    });
  }

  setBlind(id, sw) {
    return this._send_request('PUT',`/15001/${id}`, {
      15015: [{
        5536: sw.value
      }]
    });
  }

  setPayload(id,payload) {
    return this._send_request('PUT',`/15001/${id}`, payload );
  }

  setObserver(id, callback) {
    return this._send_request('GET',`/15001/${id}`, false, callback);
  }

  setObserverGroup(id, callback) {
    return this._send_request('GET',`/15004/${id}`, false, callback);
  }

  _send_request(method, command, payload, callback) {
    return throttler.enqueue(() => this._send_command(method, command, payload, callback), 'coap-req');
  }

  _send_command(method, command, payload, callback) {
    this.req = null;
    return new Promise((resolve, reject) => {
      const url = {
        protocol: 'coaps:',
        slashes: true,
        auth: null,
        host: `${this.config.hubIpAddress}:5684`,
        port: '5684',
        hostname: this.config.hubIpAddress,
        hash: null,
        search: null,
        query: null,
        method: method,
        pathname: command,
        path: command,
        href: `coaps://${this.config.hubIpAddress}:5684${command}`,
      };

      console.log(url)

      if (callback) {
        url.observe = true;
      }

      this.req = this.globalAgent.request(url, this.dtlsOpts);

      this.req.on('error', reject);

      if (payload) {
        this.req.write(JSON.stringify(payload));
      }

      this.req.on('response', (res) => {
        if (res.code.startsWith('4')) {
          reject(res.code);
        } else {
          if (callback) {
            res.on('data', dat => callback(JSON.parse(dat.toString())));
            resolve(`RC: ${res.code}`);
          }
          if ((method === 'POST' || !payload) && res.payload.toString()) {
             resolve(JSON.parse(res.payload.toString()));
          } else {
             resolve(`RC: ${res._packet.code}`);
          }
        }
      });

      this.req.end();
    });
  }
}

module.exports = TradfriCoapdtls;
