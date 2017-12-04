/*
 * Copyright (c) 2017 treban
 *
 * tradfri-coapdtls is licensed under an MIT +no-false-attribs license.
 * All rights not explicitly granted in the MIT license are reserved.
 * See the included LICENSE file for more details.
 */

'use strict';

const Tradfri = require('./tradfri-coapdtls')

var id = "id" + Math.random().toString(16).slice(2) // generate unique id

var config = {
  securityId: "security-id",      // security key
  hubIpAddress: "0.0.0.0",        // tradfri ip address
  psk: null,                      // at first connection no psk is needed
  clientId: id,                   // unique client id
};

var TradfriHub = new Tradfri(config);

TradfriHub.connect().then((key) => {
  console.log(`With the first connection, the gateway generates a session key. \n This must be stored with the unique ID for the next connection.\n  id is: ${id}\n  psk is: ${key}`);
  TradfriHub.getGatewayInfo().then((res) => {
    console.log(`Gateway connected:\n  Firmware Version: ${res['9029']}\n  NTP Server ${res['9023']}`);
  });
  TradfriHub.getAllDeviceIDs().then((res) => {
    console.log(`All bulbs ids:`);
    console.log(res);
  });
});
