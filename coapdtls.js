/*
 * Copyright (c) 2013-2015 node-coap contributors.
 *
 * node-coap is licensed under an MIT +no-false-attribs license.
 * All rights not explicitly granted in the MIT license are reserved.
 * See the included LICENSE file for more details.
 */

const util = require('util');
var optionsConv = require('./lib/option_converter'),
  Agent = require('./lib/agent'),
  parameters = require('./lib/parameters'),
  net = require('net'),
  URL = require('url'),
  globalAgent =   new Agent({type: 'udp4'})

module.exports.request = function(url, dtlsOpts, callback, payload) {
  var agent, req, ipv6, _dtls

  if (typeof url === 'string') {
    url = URL.parse(url)
  }

  if ((url.protocol === 'coaps:') || (typeof dtlsOpts === 'Object')) {
    _dtls = {
      host: url.hostname,
      port: url.port || 5684
    };
    Object.assign(_dtls, dtlsOpts);

    url.agent = new Agent({
      type: 'udp4',
      host: url.hostname,
      port: url.port || 5684
    },
    _dtls,
    (ag) => {
      var _req = ag.request(url, _dtls);
      //console.log(util.inspect(_req));
      if (payload)
        _req.write(JSON.stringify(payload));
      callback(_req);
    });
  }
}

module.exports.Agent = Agent
module.exports.globalAgent = globalAgent

module.exports.registerOption = optionsConv.registerOption
module.exports.registerFormat = optionsConv.registerFormat
module.exports.ignoreOption = optionsConv.ignoreOption

module.exports.parameters = parameters
module.exports.updateTiming = parameters.refreshTiming
module.exports.defaultTiming = parameters.defaultTiming
