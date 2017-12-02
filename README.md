tradfri-coapdtls
=======================

This sofware provides an interface for the tradfri lights
over the tradfri ip-gateway with coap+dtls protocol.

### Usage

This lib is Promise based.

```
'use strict';

const Tradfri = require('tradfri-coapdtls')

const ID = "newIdent"
const KEY = "123adc456def7890"
const IP = "192.168.178.42"

var TradfriHub = new Tradfri({securityId: KEY, hubIpAddress: IP, clientId: "Client_identity"});
TradfriHub.connect().then((val) =>
  TradfriHub.initPSK(ID).then((res) => {
      var psk=res['9091'];
      console.log(`Gateway reachable - psk generated: ${psk}`);
      TradfriHub.finish()
      TradfriHub = new Tradfri({securityId: psk, hubIpAddress: IP, clientId: ID});
      TradfriHub.connect().then((val) =>
        TradfriHub.getGatewayInfo().then( (res) =>
          console.log(`Gateway - Firmware: ${res['9029']}`)
        )
      );
    }).catch((error) =>
      console.log ("Gateway is not reachable!")
    )
);

```

### ChangeLog
* 0.0.7 - first public alpha version
* 0.0.8 - Code refactoring
* 0.0.9 - bugfix
* 0.0.10 - bugfix
* 0.0.11 - bugfix
* 0.0.12 - changed package to nativ js
* 0.0.13 - add rgb
* 0.0.14 - add psk handshake needed for gateway version 1.2.42
* 0.0.15 - bugfix
* 0.0.16 - bugfix
* 0.0.17 - added reboot and discovery mode
* 0.0.18 - code refactoring

### License
----------------------------
MIT, see LICENSE.md file.

----------------------------
#### Contributors

* [kosta](https://github.com/treban)
* [dlemper](https://github.com/dlemper)

----------------------------
#### Credits

This software is based on the node-coap package with dtls extensions
node-coap software performed by contributors :
* Matteo Collina,
* Nguyen Quoc Dinh,
* Daniel Moran Jimenez,
* Ignacio Martín,
* Christopher Hiller

DTLS extensions performed by
* J. Ian Lindsay
