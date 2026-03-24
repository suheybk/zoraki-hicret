--[[
  MenuState — Ana Menü
  Boot'tan sonra, WorldMap'ten önce gösterilir.
  Oyunu başlat / devam et / dil seç.
--]]

local StateManager = require("src.systems.state_manager")
local SaveSystem   = require("src.systems.save_system")
local AudioManager = require("src.systems.audio_manager")
local Config       = require("src.utils.config")

local MenuState = {}
MenuState.__index = MenuState

function MenuState.new()
  return setmetatable({}, MenuState)
end

function MenuState:enter(data)
  self.timer  = 0
  self.fade   = 1
  self.hover  = nil

  self.f_title  = love.graphics.newFont(64)
  self.f_sub    = love.graphics.newFont(16)
  self.f_btn    = love.graphics.newFont(18)
  self.f_small  = love.graphics.newFont(12)
  self.f_mono   = love.graphics.newFont(11)

  -- İlerleme bilgisi
  local save     = SaveSystem.get()
  local total    = 6
  local done     = #(save.completed or {})
  self.progress  = done .. "/" .. total .. " bölüm tamamlandı"
  self.has_save  = done > 0

  -- Menü butonları
  self._btns = {}
  AudioManager.stopAmbient()
end

function MenuState:update(dt)
  self.timer = self.timer + dt
  if self.fade > 0 then self.fade = math.max(0, self.fade - dt * 1.5) end

  local mx, my = Config.toLogical(love.mouse.getPosition())
  self.hover = nil
  for _, btn in ipairs(self._btns) do
    if mx >= btn.x and mx <= btn.x + btn.w and
       my >= btn.y and my <= btn.y + btn.h then
      self.hover = btn.id
    end
  end
end

function MenuState:draw()
  local W, H = Config.vw(), Config.vh()
  self._btns = {}

  -- Arka plan
  love.graphics.setColor(0.06, 0.05, 0.04, 1)
  love.graphics.rectangle("fill", 0, 0, W, H)

  -- Dekoratif yatay çizgiler
  love.graphics.setColor(0.18, 0.16, 0.12, 0.5)
  love.graphics.setLineWidth(0.5)
  for y = 0, H, 48 do love.graphics.line(0, y, W, y) end
  for x = 0, W, 80 do love.graphics.line(x, 0, x, H) end
  love.graphics.setLineWidth(1)

  -- Sol alttan gelen vurgu gradient hissi (basit şekil)
  love.graphics.setColor(0.75, 0.62, 0.35, 0.04)
  love.graphics.rectangle("fill", 0, H * 0.6, W * 0.5, H * 0.4)

  -- Başlık
  local title_y = H * 0.22
  love.graphics.setFont(self.f_title)
  love.graphics.setColor(0.88, 0.83, 0.70, 1)
  local tw = self.f_title:getWidth("HİCRET")
  love.graphics.print("HİCRET", W/2 - tw/2, title_y)

  -- Alt başlık
  love.graphics.setFont(self.f_sub)
  love.graphics.setColor(0.50, 0.46, 0.38, 0.9)
  local sub = "Zulmü İfşa Et  ·  Yolculuğu Yaşa  ·  Tanıklık Et"
  local sw  = self.f_sub:getWidth(sub)
  love.graphics.print(sub, W/2 - sw/2, title_y + 76)

  -- Yatay ayraç
  love.graphics.setColor(0.30, 0.26, 0.20, 0.6)
  love.graphics.setLineWidth(0.5)
  love.graphics.line(W/2 - 120, title_y + 102, W/2 + 120, title_y + 102)

  -- Butonlar
  local btn_w, btn_h = 280, 52
  local btn_x = W/2 - btn_w/2
  local btn_y = H * 0.52

  local buttons = {
    { id="start", label="Haritayı Aç",     sub="Bölüm seç ve oyna" },
    { id="archive",label="Tanıklık Arşivi",sub="Belgelere göz at"  },
    { id="settings",label="Ayarlar",       sub="Ses, dil"          },
  }

  for i, b in ipairs(buttons) do
    local by  = btn_y + (i-1) * (btn_h + 12)
    local hot = self.hover == b.id

    -- Buton kutusu
    love.graphics.setColor(0.10, 0.09, 0.07, hot and 0.95 or 0.6)
    love.graphics.rectangle("fill", btn_x, by, btn_w, btn_h, 6)

    local accent = { 0.78, 0.64, 0.38 }
    love.graphics.setColor(accent[1], accent[2], accent[3], hot and 0.8 or 0.25)
    love.graphics.setLineWidth(hot and 1.2 or 0.5)
    love.graphics.rectangle("line", btn_x, by, btn_w, btn_h, 6)

    -- Sol vurgu çizgisi (hover'da)
    if hot then
      love.graphics.setColor(accent[1], accent[2], accent[3], 0.9)
      love.graphics.rectangle("fill", btn_x, by, 3, btn_h, 2)
    end

    -- Etiket
    love.graphics.setFont(self.f_btn)
    love.graphics.setColor(hot and 0.95 or 0.80, hot and 0.90 or 0.76, hot and 0.72 or 0.60, 1)
    love.graphics.print(b.label, btn_x + 20, by + 10)

    -- Alt açıklama
    love.graphics.setFont(self.f_small)
    love.graphics.setColor(0.45, 0.42, 0.34, hot and 0.9 or 0.6)
    love.graphics.print(b.sub, btn_x + 20, by + 32)

    table.insert(self._btns, { id=b.id, x=btn_x, y=by, w=btn_w, h=btn_h })
  end

  -- İlerleme bilgisi
  love.graphics.setFont(self.f_mono)
  love.graphics.setColor(0.38, 0.35, 0.27, 0.8)
  love.graphics.print("// " .. self.progress, btn_x, btn_y + 3*(btn_h+12) + 8)

  -- Alt bilgi
  love.graphics.setFont(self.f_small)
  love.graphics.setColor(0.28, 0.26, 0.20, 0.6)
  local credit = "DUT Interdisciplinary Design Agency  ·  LÖVE 2D"
  local cw = self.f_small:getWidth(credit)
  love.graphics.print(credit, W/2 - cw/2, H - 28)

  -- Alıntı (sağ alt)
  love.graphics.setColor(0.28, 0.26, 0.20, 0.5)
  local q1 = '"Haber programları istatistik verir;'
  local q2 = ' oyun ise sorumluluk yükler."'
  love.graphics.print(q1, W - self.f_small:getWidth(q1) - 28, H - 46)
  love.graphics.print(q2, W - self.f_small:getWidth(q2) - 28, H - 30)

  -- Fade örtüsü
  if self.fade > 0 then
    love.graphics.setColor(0, 0, 0, self.fade)
    love.graphics.rectangle("fill", 0, 0, W, H)
  end
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setLineWidth(1)
end

function MenuState:_handlePress(x, y)
  for _, btn in ipairs(self._btns) do
    if x >= btn.x and x <= btn.x+btn.w and y >= btn.y and y <= btn.y+btn.h then
      if btn.id == "start" then
        StateManager.switch("world_map")
      elseif btn.id == "archive" then
        StateManager.switch("archive")
      elseif btn.id == "settings" then
        StateManager.push("settings")
      end
      return
    end
  end
end

function MenuState:mousepressed(x, y, btn)
  if btn == 1 then self:_handlePress(x, y) end
end
function MenuState:touchpressed(id, x, y, p)
  self:_handlePress(x, y)
end
function MenuState:keypressed(key)
  if key == "return" or key == "space" then
    StateManager.switch("world_map")
  elseif key == "escape" then
    love.event.quit()
  end
end

return MenuState
