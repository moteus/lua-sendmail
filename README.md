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

##Dependences##
* [LuaSocket](http://www.impa.br/~diego/software/luasocket)
* [LuaSec](https://github.com/brunoos/luasec)


[![Bitdeli Badge](https://d2weczhvl823v0.cloudfront.net/moteus/lua-sendmail/trend.png)](https://bitdeli.com/free "Bitdeli Badge")

