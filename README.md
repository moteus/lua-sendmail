lua-sendmail
============
[![Licence](http://img.shields.io/badge/Licence-MIT-brightgreen.svg)](LICENCE.txt)

Simple wrapper around luasoket smtp.send.<br/>
See [documentation](http://moteus.github.io/sendmail/index.html).

## Usage

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

### Send attached files as single zip archive
```Lua
local ZipWriter = require "ZipWriter"

sendmail{
  ...
  message = {
    ...
    file = {
      source = ZipWriter.source(ZipWriter.new(), {
        {"file01.txt", "path/to/file01.txt"},
        {"file02.txt", "path/to/file02.txt"},
      }),
      name = 'files.zip';
    }
  }
}
```


## Dependences
* [LuaSocket](https://luarocks.org/modules/luarocks/luasocket)
* [LuaSec](https://luarocks.org/modules/brunoos/luasec) - to support SMTPS protocol
* [Lua-cURL](https://luarocks.org/modules/moteus/lua-curl) - can be used to handle SMTP(S) protocol and IO. Still require LuaSocket to build message itself

