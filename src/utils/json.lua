--[[
  json.lua — Hafif JSON encode/decode
  Kaynak: rxi/json.lua (MIT Lisansı) - sadeleştirilmiş
--]]

local json = { _version = "0.1.2" }

local escape_char_map = {
  ["\\"] = "\\\\", ["\""] = "\\\"", ["\b"] = "\\b",
  ["\f"] = "\\f",  ["\n"] = "\\n",  ["\r"] = "\\r", ["\t"] = "\\t",
}
local escape_char_map_inv = { ["\\/"] = "/" }
for k, v in pairs(escape_char_map) do escape_char_map_inv[v] = k end

local function escape_char(c)
  return escape_char_map[c] or string.format("\\u%04x", c:byte())
end

local function encode_nil()        return "null" end
local function encode_table(val, stack)
  local res = {}
  stack = stack or {}
  if stack[val] then error("circular reference") end
  stack[val] = true
  if rawget(val, 1) ~= nil or next(val) == nil then
    for i, v in ipairs(val) do res[i] = json.encode(v, stack) end
    stack[val] = nil
    return "[" .. table.concat(res, ",") .. "]"
  else
    for k, v in pairs(val) do
      if type(k) ~= "string" then error("non-string key") end
      table.insert(res, json.encode(k, stack) .. ":" .. json.encode(v, stack))
    end
    stack[val] = nil
    return "{" .. table.concat(res, ",") .. "}"
  end
end

local type_func_map = {
  ["nil"]     = encode_nil,
  ["boolean"] = tostring,
  ["number"]  = function(v)
    if v ~= v then return "null" end
    return string.format("%.14g", v)
  end,
  ["string"]  = function(v)
    return '"' .. v:gsub('[%z\1-\31\\"]', escape_char) .. '"'
  end,
  ["table"]   = encode_table,
}

function json.encode(val, stack)
  local t = type(val)
  local f = type_func_map[t]
  if f then return f(val, stack) end
  error("cannot encode type: " .. t)
end

-- ─── Decode ────────────────────────────────────────────────────────

local parse

local function create_set(...)
  local res = {}
  for i = 1, select("#", ...) do res[select(i,...)] = true end
  return res
end

local space_chars   = create_set(" ", "\t", "\r", "\n")
local delim_chars   = create_set(" ", "\t", "\r", "\n", "]", "}", ",")
local escape_chars  = create_set("\\", "/", '"', "b", "f", "n", "r", "t", "u")
local literals      = { ["true"] = true, ["false"] = false, ["null"] = nil }

local function next_char(str, idx, set, negate)
  for i = idx, #str do
    if set[str:sub(i,i)] ~= negate then return i end
  end
  return #str + 1
end

local function decode_error(str, idx, msg)
  local line = 1
  for i = 1, idx - 1 do if str:sub(i,i) == "\n" then line = line + 1 end end
  error(string.format("%s at line %d col %d", msg, line, idx - 1))
end

local function parse_string(str, i)
  local res = ""
  local j = i + 1
  while j <= #str do
    local c = str:sub(j,j)
    if c == '"' then return res, j + 1
    elseif c == "\\" then
      j = j + 1
      local d = str:sub(j,j)
      if d == "u" then
        local n = tonumber(str:sub(j+1, j+4), 16)
        if not n then decode_error(str, j, "invalid unicode escape") end
        res = res .. (n < 128 and string.char(n) or "?")
        j = j + 4
      else
        res = res .. (escape_char_map_inv["\\" .. d] or decode_error(str, j, "invalid escape char"))
      end
    else
      res = res .. c
    end
    j = j + 1
  end
  decode_error(str, i, "unterminated string")
end

local function parse_number(str, i)
  local j = next_char(str, i, delim_chars)
  local s = str:sub(i, j-1)
  local n = tonumber(s)
  if not n then decode_error(str, i, "invalid number '"..s.."'") end
  return n, j
end

local function parse_literal(str, i)
  local j = next_char(str, i, delim_chars)
  local s = str:sub(i, j-1)
  if not literals[s] then decode_error(str, i, "invalid literal '"..s.."'") end
  return literals[s], j
end

local function parse_array(str, i)
  local res = {}
  local n   = 1
  i = i + 1
  while true do
    i = next_char(str, i, space_chars, true)
    if str:sub(i,i) == "]" then return res, i+1 end
    local val; val, i = parse(str, i)
    res[n] = val; n = n + 1
    i = next_char(str, i, space_chars, true)
    local c = str:sub(i,i)
    if c ~= "," and c ~= "]" then decode_error(str, i, "expected ']' or ','") end
    if c == "]" then return res, i+1 end
    i = i + 1
  end
end

local function parse_object(str, i)
  local res = {}
  i = i + 1
  while true do
    i = next_char(str, i, space_chars, true)
    if str:sub(i,i) == "}" then return res, i+1 end
    if str:sub(i,i) ~= '"' then decode_error(str, i, "expected string key") end
    local key; key, i = parse_string(str, i)
    i = next_char(str, i, space_chars, true)
    if str:sub(i,i) ~= ":" then decode_error(str, i, "expected ':'") end
    i = next_char(str, i+1, space_chars, true)
    local val; val, i = parse(str, i)
    res[key] = val
    i = next_char(str, i, space_chars, true)
    local c = str:sub(i,i)
    if c ~= "," and c ~= "}" then decode_error(str, i, "expected '}' or ','") end
    if c == "}" then return res, i+1 end
    i = i + 1
  end
end

local char_func_map = {
  ['"'] = parse_string, ["0"] = parse_number, ["1"] = parse_number,
  ["2"] = parse_number, ["3"] = parse_number, ["4"] = parse_number,
  ["5"] = parse_number, ["6"] = parse_number, ["7"] = parse_number,
  ["8"] = parse_number, ["9"] = parse_number, ["-"] = parse_number,
  ["t"] = parse_literal,["f"] = parse_literal,["n"] = parse_literal,
  ["["] = parse_array,  ["{"] = parse_object,
}

parse = function(str, idx)
  local c = str:sub(idx, idx)
  local f = char_func_map[c]
  if f then return f(str, idx) end
  decode_error(str, idx, "unexpected character '" .. c .. "'")
end

function json.decode(str)
  if type(str) ~= "string" then error("expected string") end
  local res, idx = parse(str, next_char(str, 1, space_chars, true))
  idx = next_char(str, idx, space_chars, true)
  if idx <= #str then decode_error(str, idx, "trailing garbage") end
  return res
end

return json
