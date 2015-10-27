-- sendmail.lua v0.1.4 (2015-10)

-- Copyright (c) 2013-2015 Alexey Melnichuk
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.

------------------------------------------------------------
local DEFAULT_CHARSET = 'windows-1251'
local DEFAULT_ENCODE  = 'base64'
local DEFAULT_HEADERS = {
  ['x-mailer'] = 'Cool mailer'
}
local DEFAULT_OPTIONS = {
  confirm_sending = false;
}
------------------------------------------------------------

local smtp   = require("socket.smtp")
local socket = require("socket")
local ltn12  = require("ltn12")
local mime   = require("mime")
local string = require("string")
local table  = require("table")
local io     = require("io")

local function basename(f)
  return (string.match(f, "[^\\/]+$"))
end

local function split(str, sep, plain)
  local b, res = 1, {}
  while b <= #str do
    local e, e2 = string.find(str, sep, b, plain)
    if e then
      res[#res + 1] = string.sub(str, b, e-1)
      b = e2 + 1
    else
      res[#res + 1] = string.sub(str, b)
      break
    end
  end
  return res
end

local function append(dst, src)
  for k,v in pairs(src) do 
    dst[k] = v
  end
  return dst
end

local function clone(t)
  return append({}, t)
end

local function prequire(name)
  local ok, mod = pcall(require, name)
  if not ok then return nil, mod end
  return mod, name
end

local ENCODERS = {
  ['base64']           = function(msg) return mime.b64(msg) end,
  ['quoted-printable'] = function(msg) return mime.qp (msg) end,
}

local function encoders(t)
  if t == nil then
    return ENCODERS['none']
  end
  local e = ENCODERS[t:lower()]
  if not e then return nil, 'unknown encode type :' .. t end
  return e
end

local function encode_title(title)
  local charset = DEFAULT_CHARSET
  local encode  = DEFAULT_ENCODE

  if type(title) == 'table' then
    charset  = title.charset or charset
    encode   = title.encode or encode
    title    = title[1] or title.title
  end

  if title and #title > 0 then
    local encoder, err = encoders(encode)
    if not encoder then return nil, err end
    local str = encoder(title)
    if str then return "=?" .. charset .. "?" .. encode:sub(1,1) .. "?" .. str .. "?=" end
    return title
  else 
    return ""
  end
end

local function make_t_File (fileName)
  local src
  local name 
  local mime_type   = 'application/octet-stream'
  local disposition = 'attachment'
  local encode      = 'base64'
  local headers     = {}

  if type(fileName) == 'string' then
    local fh, err = io.open(fileName, "rb")
    if not fh then return nil, err end
    src = ltn12.source.file(fh)
    name = basename(fileName)
  elseif type(fileName) == 'table' then
    name = fileName.name
    local path = fileName.path
    local data = fileName.data
    local file = fileName.file
    if (not name) and path then name = basename(path) end
    if not name then return nil, 'file name require' end
    if data then src = ltn12.source.string(data)
    elseif file then src = ltn12.source.file(file)
    elseif path then 
      local fh, err = io.open(path, "rb")
      if not fh then return nil, err end
      src = ltn12.source.file(fh)
    else return nil, 'need file/path/data' end
    mime_type   = fileName.mime_type   or mime_type
    disposition = fileName.disposition or disposition
    encode      = fileName.encode      or encode
    if fileName.headers then append(headers, fileName.headers) end
  end

  name = encode_title(name)

  assert(src)
  assert(name)
  local encoder, err = mime.encode(encode)
  if not encoder then return nil, err end

  return {
    headers = append(headers, {
      ["content-type"]              = mime_type   .. '; name="'    .. name ..'"',
      ["content-disposition"]       = disposition .. '; filename="'.. name ..'"',
      ["content-transfer-encoding"] = encode,
    }),
    body = ltn12.source.chain(src,
      ltn12.filter.chain(encoder,mime.wrap(encode))
    )
  }
end

local function make_t_Text(data, mime_type, charset, encode)
  local headers = {}
  if type(data) == 'table' then
    charset   = data.charset   or charset
    encode    = data.encode    or encode
    mime_type = data.mime_type or mime_type
    if data.headers then append(headers, data.headers) end
    data      = data[1]        or data.data
  end

  data = data or ''

  local src
  if encode:lower() == '8bit' then src = mime.eol(0, data)
  else
    local encoder, err = mime.encode(encode)
    if not encoder then return nil, err end
    src = ltn12.source.chain(ltn12.source.string(data),
      ltn12.filter.chain(encoder,mime.wrap(encode))
    )
  end
  return {
    headers = append(headers, {
      ["content-type"] = mime_type .. '; charset="' .. charset .. '"',
      ["content-transfer-encoding"] = encode,
    });
    body = src;
  }
end

local function make_t_Body(message)
  assert(message)
  local body = {}
  body.preamble = message.preamble
  body.epilogue = message.epilogue

  if message.text then
    local t, err = make_t_Text(message.text, 'text/plain', DEFAULT_CHARSET, '8bit')
    if not t then return nil, err end
    table.insert(body, t)
  end

  if message.html then
    local t, err = make_t_Text(message.html, 'text/html', DEFAULT_CHARSET, DEFAULT_ENCODE)
    if not t then return nil, err end
    table.insert(body, t)
  end

  if message.file then
    local files = message.file
    if type(files) == "string"  then files = {files} end
    if files.name or files.path then files = {files} end
    for _, file in ipairs(files) do
      local t, err = make_t_File(file)
      if not t then return nil, err end
      table.insert(body, t);
    end
  end

  return body
end

local function make_t_to(to,options)
  local to_ = {}

  local address = to.address
  if type(address) == "string" then
    address = split(address, '%s*[,;]%s*')
  end

  for _,addr in ipairs(address) do 
    addr = "<" .. addr .. ">"
    if options.confirm_sending then
      addr = addr .. " NOTIFY=SUCCESS,FAILURE"
    end
    table.insert(to_,addr)
  end
  return to_
end

local function make_from(t)
  local str = encode_title(t)
  if t.address then str = str .. '<' .. t.address .. '>' end
  return str 
end

local luasec_create do local ssl = prequire "ssl" if ssl then

-- based on  http://curl.haxx.se/docs/sslcerts.html

local DEFAULT_CA_NAME = "curl-ca-bundle.crt"

local function find_ca_by_env()
  local env = setmetatable({},{__index = function(_, name) return os.getenv(name) end})

  if env.SSL_CERT_DIR then return nil, env.SSL_CERT_DIR end

  if env.SSL_CERT_FILE then return env.SSL_CERT_FILE  end
end

local function find_ca_by_fs(name)
  local path = prequire "path"
  if not (path and path.IS_WINDOWS) then return name end

  if name then
    if path.isfile(name)        then return name end
    if path.dirname(name) ~= "" then return name end
  else name = DEFAULT_CA_NAME end

  local env = setmetatable({},{__index = function(_, name) return os.getenv(name) end})

  local paths = {
    '.',
    path.join(env.windir, "System32"),
    path.join(env.windir, "SysWOW64"),
    env.windir,
  }
  for _, p in ipairs(split(env.path, ';', true)) do paths[#paths + 1] = p end

  for _, p in ipairs(paths) do
    p = path.join(path.fullpath(p), name)
    if path.isfile(p) then
      return p
    end
  end
end

local function has(t,k)
  if type(t) == "table" then
    for _, v in ipairs(t) do
      if k == v then return true end
    end
    return false
  end
  return t == k
end

luasec_create = function(params)
  assert(params)

  if params == true then params = {} 
  elseif type(params) == 'string' then params = {protocol = params}
  else params = clone(params) end

  params.mode      = params.mode     or "client"
  params.protocol  = params.protocol or "tlsv1"
  params.verify    = params.verify   or {"peer", "fail_if_no_peer_cert"}
  params.options   = params.options  or "all"

  assert(params.mode == "client")

  if not has(params.verify, "none") then repeat
    if params.cafile or params.capath then
      if params.cafile then
        params.cafile = find_ca_by_fs(params.cafile) or params.cafile
      end
      break
    end

    local cafile, capath = find_ca_by_env()
    if cafile or capath then
      params.cafile, params.capath = cafile, capath
      break
    end

    params.cafile = find_ca_by_fs()
  until true end

  return function()

    local sock = socket.tcp()

    return setmetatable({
      connect = function(_, host, port)
        local r, e = sock:connect(host, port)
        if not r then return r, e end
        sock = ssl.wrap(sock, params)
        return sock:dohandshake()
      end
    }, {
      __index = function(t,n)
        local fn = function(_, ...)
          return sock[n](sock, ...)
        end
        t[n] = fn
        return fn
      end
    })
  end
end

end end

--------------------------------------------------------
-- make message for smtp.send
--[[!---------------------------------------------------

@param from = address or {
   title / [1]   = string;
   address = string;
   charset = string;
   encode  = string;
}

@param to = address(string) or {
   title / [1] = string;
   address     = string/array of strings
   charset = string;
   encode  = string;
}

@param smtp_server = address or {
   address  = string,
   user     = string,
   password = string,
}

@param message = {
   subject =  title or {
     title / [1]   = string;
     charset = string;
     encode  = string;
   }

   text  = text or {
     data / [1]   = string;
     charset   = string;
     encode    = string;
     mime_type = string
     headers   = table;
   }

   html  = text or {
     data / [1]   = string;
     charset   = string;
     encode    = string;
     mime_type = string
     headers   = table;
   }

   file = file path (string)
   file = {
      name = string;

      -- one of them
      path = string;
      data = string;
      file = file handle(io.file);

     charset   = string;
     encode    = string;
     mime_type = string
     headers   = table;
   }

   preamble = string;
   epilogue = string;
}

@param options = {
  confirm_sending = true
}
--!]]
local function CreateMail(from, to, smtp_server, message, options)

  local smtp_port = smtp_server.port

  local create_socket = smtp_server.create
  if smtp_server.ssl then
    smtp_port = smtp_port or 465

    if not create_socket then
      if not luasec_create then return nil, "SSL not supported" end
      local err create_socket, err = luasec_create(smtp_server.ssl)
      if not create_socket then return nil, err end
    else
      local base_create_socket = create_socket
      create_socket = function()
        return base_create_socket(smtp_server.ssl)
      end;
    end
  end

  options = options or DEFAULT_OPTIONS 
  if type(from)        == 'string' then  from        = { address = from }        end
  if type(to)          == 'string' then  to          = { address = to }          end
  if type(smtp_server) == 'string' then  smtp_server = { address = smtp_server } end
  if not message then  message = {}
  elseif type(message) == 'string' then  message = { subject = message }
  elseif message[1] then
    message = clone(message)
    if not message.subject then 
      message[1], message.subject = nil, message[1]
      if message[2] and not message.text then
        message[2], message.text = nil, message[2]
      end
    elseif not message.text then
      message[1], message.text = nil, message[1]
    end
  end

  -- This headers uses only by mail clients. smtp.send ignores them.
  local headers = clone(DEFAULT_HEADERS)

  local err
  headers['from'], err  = make_from(from)
  if not headers['from'] then return nil, err end

  headers['to'], err = encode_title(to)
  if not headers['to'] then return nil, err end

  to = make_t_to(to, options)
  if (not to and not to[1]) then return nil, 'unknown recipient' end
  headers['to'] = headers['to'] .. (to[1]:match('%b<>') or '')

  if options.confirm_sending then
    headers['Return-Receipt-To']="<" .. (from.address or '') .. ">"
  end

  local source = {}
  if message then
    if message.headers then 
      headers = append(clone(message.headers), headers)
    end

    headers.subject, err = encode_title(message.subject)
    if not headers.subject then
      return nil, err
    end

    local body, err = make_t_Body(message)
    if not body then return nil, err end
    source.body = body
  end
  source.headers = headers
  return {
    from     = from.address and "<" .. from.address .. ">" or '',
    rcpt     = to,
    server   = smtp_server.address,
    port     = smtp_port,
    user     = smtp_server.user,
    password = smtp_server.password,
    create   = create_socket,
    source   = smtp.message(source)
  }
end

local function sendmail(...)
  local msg, err;
  if type((...)) == 'table' and select('#', ...) == 1 then
    local params = ...
    msg, err = CreateMail(params.from, params.to, params.server, params.message, params.options)
  else
    msg, err = CreateMail(...)
  end
  if not msg then return nil, err end
  return smtp.send(msg)
end

return sendmail