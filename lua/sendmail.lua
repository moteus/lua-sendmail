local smtp   = require("socket.smtp")
local socket = require("socket")
local ltn12  = require("ltn12")
local mime   = require("mime")

local function basename(f)
  return (string.match(f, "[^\\/]+$"))
end

local function split(text, sep, plain)
  local res={}
  local searchPos=1
  while true do
    local matchStart, matchEnd=string.find(text, sep, searchPos, plain)
    if matchStart and matchEnd >= matchStart then
      table.insert(res, string.sub(text, searchPos, matchStart-1))
      searchPos=matchEnd+1
    else
      table.insert(res, string.sub(text, searchPos))
      break
    end
  end
  return res
end

local DEFAULT_CHARSET = 'windows-1251'
local DEFAULT_ENCODE  = 'base64'
local DEFAULT_HEADERS = {
  ['x-mailer'] = 'Cool mailer'
}
local DEFAULT_OPTIONS = {
  confirm_sending = false;
}

local function clone(t)
  local o = {}
  for k, v in pairs(t) do o[k] = v end
  return o
end

local function append(dst, src)
  for k,v in pairs(src) do 
    dst[k] = v
  end
  return dst
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
    if fileName.headers then headers = clone(fileName.headers) end
  end

  assert(src)
  assert(name)
  local encoder, err = mime.encode(encode)
  if not encode then return nil, err end

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
    if data.headers then headers = clone(data.headers) end
    data      = data[1]        or data.data
  end

  data = data or ''

  local src
  if encode:lower() == '8bit' then src = mime.eol(0, data)
  else
    local encoder, err = mime.encode(encode)
    if not encode then return nil, err end
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
    local addr = "<" .. addr .. ">"
    if options.confirm_sending then
      addr = addr .. " NOTIFY=SUCCESS,FAILURE"
    end
    table.insert(to_,addr)
  end
  return to_
end

local function encode_title(title)
  local charset = DEFAULT_CHARSET
  local encode  = DEFAULT_ENCODE

  if type(title) == 'table' then
    charset = title.charset or charset
    encode   = title.encode or encode
    title    = title[1] or title.title
  end

  if title and #title > 0 then
    local encoder, err = encoders(encode)
    if not encode then return nil, err end
    local str = encoder(title)
    if str then return "=?" .. charset .. "?" .. encode:sub(1,1) .. "?" .. str .. "?=" end
    return title
  else 
    return ""
  end
end

local function make_from(t)
  local str = encode_title(t)
  if t.address then str = str .. '<' .. t.address .. '>' end
  return str 
end

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
  options = options or DEFAULT_OPTIONS 
  if type(from)        == 'string' then  from        = { address = from }        end
  if type(to)          == 'string' then  to          = { address = to }          end
  if type(smtp_server) == 'string' then  smtp_server = { address = smtp_server } end
  if type(message)     == 'string' then  message     = { text    = message }     end


  -- Эти заголовки показываются только в почтовой программе и игнорируются smtp.send
  local headers = clone(DEFAULT_HEADERS)

  headers['from'] = make_from(from)

  local to = make_t_to(to, options)
  if (not to and not to[1]) then return nil, 'unknown recipient' end
  headers['to'] = encode_title(to) .. (to[1]:match('%b<>') or '')

  if options.confirm_sending then
    headers['Return-Receipt-To']="<" .. (from.address or '') .. ">"
  end

  local source = {}
  if message then
    if message.headers then 
      headers = append(clone(message.headers), headers)
    end

    headers.subject = encode_title(message.subject)

    local body, err = make_t_Body(message)
    if not body then return nil, err end
    source.body = body
  end
  source.headers = headers
  return {
    from     = from.address and "<" .. from.address .. ">" or '',
    rcpt     = to,
    server   = smtp_server.address,
    user     = smtp_server.user,
    password = smtp_server.password,
    source   = smtp.message(source)
  }
end

local function sendmail(...)
  local msg, err = CreateMail(...)
  if not msg then return nil, err end
  return smtp.send(msg)
end

return sendmail