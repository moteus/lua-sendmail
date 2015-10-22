lua-sendmail
============
[![Licence](http://img.shields.io/badge/Licence-MIT-brightgreen.svg)](LICENCE.txt)

Simple wrapper around luasoket smtp.send.<br/>
See [documentation](http://moteus.github.io/sendmail/index.html).
##Usage

```Lua
local sendmail = require "sendmail"
local from, to, server = 'from@some.mail', 'to@some.mail', '127.0.0.1'

sendmail(from, to, server, {"Subject", [[
  This is mail body.
]],
  file = {
    name = 'message.txt';
    data = 'file content';
  };
})
```

### Send mail with SSL/TLS connection (using LuaSec)
```Lua
sendmail{
  server = {
    ssl = {
      protocol = "sslv3",
      verify   = {"peer", "fail_if_no_peer_cert"},
      options  = {"all", "no_sslv2"},
    },
    address  = ...;
    user     = ...;
    password = ...;
  },
  ...
}
```

### Send mail with SSL/TLS connection (using custom SSL connection)
```Lua
-- I use lua-lluv-ssl library.
local ut     = require "lluv.utils"
local ssl    = require "lluv.ssl"
local socket = require "lluv.ssl.luasocket"

-- this is asyncronus call
ut.corun(sendmail, {
  server = {
    ssl = ssl.context{
      protocol = "sslv3",
      verify   = {"peer", "fail_if_no_peer_cert"},
      options  = {"all", "no_sslv2"},
    },
    create = socket.ssl;
    address  = ...;
    user     = ...;
    password = ...;
  },
  ...
})
```

##Dependences##
* [LuaSocket](http://www.impa.br/~diego/software/luasocket)


[![Bitdeli Badge](https://d2weczhvl823v0.cloudfront.net/moteus/lua-sendmail/trend.png)](https://bitdeli.com/free "Bitdeli Badge")

