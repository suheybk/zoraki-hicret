--[[
  InputManager — Fare ve Dokunmatik Birleşik Girdi
  
  Tüm input sanal koordinatlara çevrilmiş olarak gelir (Config üzerinden).
  Kullanım:
    InputManager.isDown("action")   → bool
    InputManager.justPressed("action") → bool (sadece o frame)
--]]

local InputManager = {}

-- Tuş haritası (klavye)
local _keymap = {
  action    = {"space", "return"},
  back      = {"escape", "backspace"},
  map       = {"m"},
  archive   = {"a"},
  pause     = {"p"},
}

local _held    = {}
local _pressed = {}   -- bu frame basılanlar
local _released= {}   -- bu frame bırakılanlar

function InputManager.init()
  _held     = {}
  _pressed  = {}
  _released = {}
end

function InputManager.update(dt)
  -- Frame başında pressed/released sıfırla
  _pressed  = {}
  _released = {}
end

--- Klavye basımı (main.lua'dan çağrılır)
function InputManager.keypressed(key)
  _held[key]    = true
  _pressed[key] = true
end

function InputManager.keyreleased(key)
  _held[key]     = false
  _released[key] = true
end

--- Eylem tabanlı sorgu
function InputManager.isDown(action)
  local keys = _keymap[action]
  if not keys then return false end
  for _, k in ipairs(keys) do
    if _held[k] then return true end
  end
  return false
end

function InputManager.justPressed(action)
  local keys = _keymap[action]
  if not keys then return false end
  for _, k in ipairs(keys) do
    if _pressed[k] then return true end
  end
  return false
end

--- Ham tuş sorgusu
function InputManager.keyDown(key)    return _held[key]    == true end
function InputManager.keyPressed(key) return _pressed[key] == true end

return InputManager
