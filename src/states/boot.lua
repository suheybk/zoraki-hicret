--[[
  Boot — Yükleme & Başlangıç Durumu
  Assetleri yükler, ses sistemini başlatır, WorldMap'e geçer.
--]]

local StateManager  = require("src.systems.state_manager")
local SaveSystem    = require("src.systems.save_system")
local I18n          = require("src.systems.i18n")
local AudioManager  = require("src.systems.audio_manager")
local Config        = require("src.utils.config")

local BootState = {}
BootState.__index = BootState

function BootState.new()
  return setmetatable({}, BootState)
end

function BootState:enter(data)
  self.progress     = 0
  self.step         = 0
  self.done         = false
  self.timer        = 0
  self.fade         = 1
  self.finish_timer = nil

  -- Yükleme adımları (her frame 1 adım işlenir)
  self.steps = {
    function() SaveSystem.load() end,
    function()
      local lang = SaveSystem.getSetting("lang", "tr")
      I18n.init(lang)
    end,
    function()
      -- Ses sistemini başlat (SFX ön-sentezi burada yapılır)
      -- love.audio.setVolume(1.0) ile master kontrol
      love.audio.setVolume(1.0)
      AudioManager.init()
    end,
    function()
      -- Harita ambiyansını önceden sentezle
      -- (ilk açılışta gecikme olmaması için)
    end,
  }
  self.total = #self.steps

  self.font_title = love.graphics.newFont(32)
  self.font_sub   = love.graphics.newFont(14)
end

function BootState:update(dt)
  self.timer = self.timer + dt
  if self.fade > 0 then self.fade = math.max(0, self.fade - dt*2) end

  if self.step < self.total then
    local fn = self.steps[self.step + 1]
    local ok, err = pcall(fn)
    if not ok then print("[Boot] Hata: " .. tostring(err)) end
    self.step     = self.step + 1
    self.progress = self.step / self.total

  elseif not self.done then
    self.done         = true
    self.finish_timer = 0.6
  end

  if self.done then
    self.finish_timer = self.finish_timer - dt
    if self.finish_timer <= 0 then
      StateManager.switch("menu")
    end
  end
end

function BootState:draw()
  local W, H = Config.vw(), Config.vh()
  love.graphics.setColor(0.05, 0.04, 0.03, 1)
  love.graphics.rectangle("fill", 0, 0, W, H)

  -- Başlık
  love.graphics.setFont(self.font_title)
  love.graphics.setColor(0.88, 0.83, 0.70, 1)
  local title = "HİCRET"
  local tw = self.font_title:getWidth(title)
  love.graphics.print(title, W/2 - tw/2, H/2 - 60)

  -- Alt yazı
  love.graphics.setFont(self.font_sub)
  love.graphics.setColor(0.45, 0.42, 0.35, 1)
  local sub = "Yükleniyor..."
  local sw = self.font_sub:getWidth(sub)
  love.graphics.print(sub, W/2 - sw/2, H/2 + 20)

  -- Progress bar
  local bw, bh = 300, 2
  local bx = W/2 - bw/2
  local by = H/2 + 50
  love.graphics.setColor(0.18, 0.16, 0.13, 1)
  love.graphics.rectangle("fill", bx, by, bw, bh)
  love.graphics.setColor(0.72, 0.62, 0.42, 1)
  love.graphics.rectangle("fill", bx, by, bw * self.progress, bh)

  -- Fade
  if self.fade > 0 then
    love.graphics.setColor(0, 0, 0, self.fade)
    love.graphics.rectangle("fill", 0, 0, W, H)
  end
  love.graphics.setColor(1,1,1,1)
end

return BootState
