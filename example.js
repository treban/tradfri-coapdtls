/*
 * Copyright (c) 2017 treban
 *
 * tradfri-coapdtls is licensed under an MIT +no-false-attribs license.
 * All rights not explicitly granted in the MIT license are reserved.
 * See the included LICENSE file for more details.
 */

'use strict';

const Tradfri = require('tradfri-coapdtls')

var config = {
  securityId: "123adc456def7890",
  hubIpAddress: "192.168.178.42",
  psk: null,
  clientId: "newIdent"
}

var TradfriHub = new Tradfri(config);
TradfriHub.connect().then((val) =>
  console.log(`Gateway online - psk generated: ${psk}`);
  TradfriHub.initPSK(ID).then((res) => {
      var psk=res['9091'];
      console.log(`Gateway online - psk generated: ${psk}`);
      TradfriHub.finish()
      TradfriHub = new Tradfri({securityId: psk, hubIpAddress: IP, clientId: ID});
      TradfriHub.connect().then((val) =>
        TradfriHub.getGatewayInfo().then( (res) =>
          console.log(`Gateway online - Firmware: ${res['9029']}`)
        )
      );
    }).catch((error) =>
      console.log ("Gateway is not reachable!")
    )
);
