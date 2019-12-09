tradfri-coapdtls
=======================

This sofware provides an interface for the tradfri lights via the tradfri ip-gateway.

### Usage

This lib is Promise based.

```
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
* 0.0.18 - added smart wall plug
* 0.1.0 - code refactoring - es2015 syntax and blind support

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
