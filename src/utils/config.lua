--[[
  Config — Çözünürlük & Viewport Yönetimi
  Sanal çözünürlük: 1280×720 (16:9)
  Tüm koordinatlar sanal uzayda; fiziksel → sanal dönüşüm burada.
--]]

local Config = {}

Config.VIRTUAL_W = 1280
Config.VIRTUAL_H = 720

-- Fiziksel ekran boyutları (resize ile güncellenir)
Config.screenW = 800
Config.screenH = 600

-- İç viewport hesabı
local _ox, _oy, _scale = 0, 0, 1
local _canvas

local function _recalc()
  local sw, sh = Config.screenW, Config.screenH
  local sx = sw / Config.VIRTUAL_W
  local sy = sh / Config.VIRTUAL_H
  _scale = math.min(sx, sy)
  _ox = math.floor((sw - Config.VIRTUAL_W * _scale) / 2)
  _oy = math.floor((sh - Config.VIRTUAL_H * _scale) / 2)
end

function Config.init()
  Config.screenW, Config.screenH = love.graphics.getDimensions()
  _recalc()
end

function Config.applyWindowSettings()
  -- Yüksek DPI ekranlarda pixel density bilgisini al
  local dpi = love.window.getDPIScale()
  Config.dpi = dpi
end

function Config.onResize(w, h)
  Config.screenW, Config.screenH = w, h
  _recalc()
end

--- Fiziksel koordinatı sanal koordinata çevirir
function Config.toLogical(x, y)
  return (x - _ox) / _scale, (y - _oy) / _scale
end

--- Sanal koordinatı fiziksel koordinata çevirir
function Config.toPhysical(x, y)
  return x * _scale + _ox, y * _scale + _oy
end

--- Viewport push — tüm çizimler sanal uzayda yapılır
function Config.pushViewport()
  love.graphics.push()
  love.graphics.translate(_ox, _oy)
  love.graphics.scale(_scale, _scale)
end

function Config.popViewport()
  love.graphics.pop()
  -- Letterbox/pillarbox siyah barları çiz
  love.graphics.setColor(0, 0, 0, 1)
  if _ox > 0 then
    love.graphics.rectangle("fill", 0, 0, _ox, Config.screenH)
    love.graphics.rectangle("fill", Config.screenW - _ox, 0, _ox + 1, Config.screenH)
  end
  if _oy > 0 then
    love.graphics.rectangle("fill", 0, 0, Config.screenW, _oy)
    love.graphics.rectangle("fill", 0, Config.screenH - _oy, Config.screenW, _oy + 1)
  end
  love.graphics.setColor(1, 1, 1, 1)
end

--- Sanal genişlik/yükseklik kısayolları
function Config.vw() return Config.VIRTUAL_W end
function Config.vh() return Config.VIRTUAL_H end
function Config.cx() return Config.VIRTUAL_W / 2 end
function Config.cy() return Config.VIRTUAL_H / 2 end

return Config
