tradfri-coapdtls
=======================

This sofware provides an interface for the tradfri lights
over the tradfri ip-gateway with coap+dtls protocol.

========

### Usage

This lib is Promise based.

```
(coffeecode)

  TradfriCoapdtls = require('tradfri-coapdtls')

  tradfriHub = new TradfriCoapdtls({securityId: @secID , hubIpAddress: @hubIP})
  tradfriHub.connect().then( (val)=>
    tradfriHub.getGatewayInfo().then( (res) =>
      console.log("Gateway online - Firmware: #{res['9029']}")
    ).catch( (error) =>
      console.log ("Gateway is not reachable!")
    )
  )
  tradfriHub.setDevice(@address, {
    state: 1,
    brightness: 254
  },5).then( (res) =>
    console.log("New value send to device")
  )

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

### License
----------------------------
MIT, see LICENSE.md file.

----------------------------

This software is based on the node-coap package with dtls extensions
node-coap software performed by contributors :
Matteo Collina,
Nguyen Quoc Dinh,
Daniel Moran Jimenez,
Ignacio Martín,
Christopher Hiller

DTLS extensions performed by
J. Ian Lindsay
