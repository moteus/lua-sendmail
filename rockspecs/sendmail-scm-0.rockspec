package = "sendmail"
version = "scm-0"
source = {
  url = "https://github.com/moteus/lua-sendmail/archive/master.zip",
  dir = "lua-sendmail-master",
}

description = {
  summary = "Simple wrapper around luasoket smtp.send",
  detailed = [[
  ]],
  homepage = "https://github.com/moteus/lua-sendmail",
  -- license = ""
}

dependencies = {
  "lua >= 5.1",
  "luasocket >= 2.0",
}

build = {
  type = "builtin",
  copy_directories = {"docs"},
  modules = {
    ["sendmail" ] = "lua/sendmail.lua",
  }
}



