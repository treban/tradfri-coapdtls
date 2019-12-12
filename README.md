tradfri-coapdtls
=======================

This sofware provides an interface for the tradfri lights via the tradfri ip-gateway.

IMPORTANT: With version 0.1.0 the connection process was changed. Please check the example.

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
[-> see CHANGELOG](https://github.com/treban/tradfri-coapdtls/blob/master/CHANGELOG.md)

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
