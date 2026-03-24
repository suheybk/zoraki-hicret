--[[
  I18n — Çok Dosyalı Çok Dilli Destek (TR / EN / AR)
  Ana: data/i18n/{lang}.json
  Bölüm: data/i18n/chapter_{id}_{lang}.json
--]]

local I18n = {}
local _lang = "tr"
local _data = {}
local _rtl  = { ar=true, fa=true, ur=true }

local function _readJSON(path)
  local ok, raw = pcall(love.filesystem.read, path)
  if not ok or not raw then return nil end
  local json = require("src.utils.json")
  local ok2, tbl = pcall(json.decode, raw)
  return ok2 and tbl or nil
end

local function _merge(a, b)
  if type(b) ~= "table" then return end
  for k, v in pairs(b) do
    if type(v) == "table" and type(a[k]) == "table" then _merge(a[k], v)
    else a[k] = v end
  end
end

function I18n.init(lang)
  _lang = lang or "tr"
  _data = {}
  local main = _readJSON("data/i18n/" .. _lang .. ".json")
  if main then _merge(_data, main) end
  if _lang ~= "tr" then
    I18n._fallback = _readJSON("data/i18n/tr.json") or {}
  else
    I18n._fallback = nil
  end
end

function I18n.loadChapter(chapter_id)
  local path = "data/i18n/chapter_" .. chapter_id .. "_" .. _lang .. ".json"
  local tbl = _readJSON(path)
  if tbl then _merge(_data, tbl)
  elseif _lang ~= "tr" then
    local fb = _readJSON("data/i18n/chapter_" .. chapter_id .. "_tr.json")
    if fb then _merge(_data, fb) end
  end
end

function I18n.setLang(lang) I18n.init(lang) end
function I18n.getLang()     return _lang end
function I18n.isRTL()       return _rtl[_lang] == true end

function I18n.t(key, vars)
  local parts = {}
  for p in key:gmatch("[^%.]+") do table.insert(parts, p) end
  local function _dig(tbl)
    local v = tbl
    for _, p in ipairs(parts) do
      if type(v) ~= "table" then return nil end
      v = v[p]
    end
    return v
  end
  local val = _dig(_data)
  if val == nil and I18n._fallback then val = _dig(I18n._fallback) end
  if val == nil then return "[" .. key .. "]" end
  if vars and type(val) == "string" then
    val = val:gsub("{(%w+)}", function(k)
      return tostring(vars[k] or "{" .. k .. "}")
    end)
  end
  return tostring(val)
end

return I18n
