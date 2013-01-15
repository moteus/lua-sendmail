package = "sendmail"
version = "scm-0"
source = {
  url = "https://github.com/moteus/lua-sendmail/archive/master.zip",
  dir = "lua-log-master",
}

description = {
  summary = "Simple wrapper around luasoket smtp.send",
  detailed = [[
  ]],
  homepage = "lua-sendmail",
  -- license = ""
}

dependencies = {
  "lua >= 5.1",
  "luasocket",
}

build = {
  type = "builtin",
  copy_directories = {"docs"},
  modules = {
    ["sendmail" ] = "lua/sendmail.lua",
  }
}



