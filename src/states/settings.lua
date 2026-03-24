--[[
  SettingsState — Ayarlar Ekranı
  
  Bölümler:
    SES       — Ambiyans ve SFX seviyeleri (slider)
    DİL       — TR / EN / AR seçimi
    HAKKINDA  — Proje notu
    
  StateManager.push("settings") ile üst katman olarak açılır,
  pop() ile geri döner — ana menü veya world_map üzerinde çalışır.
--]]

local StateManager  = require("src.systems.state_manager")
local AudioManager  = require("src.systems.audio_manager")
local SaveSystem    = require("src.systems.save_system")
local I18n          = require("src.systems.i18n")
local Config        = require("src.utils.config")

local SettingsState = {}
SettingsState.__index = SettingsState

-- ─── Sabitler ────────────────────────────────────────────────────────

local W_PANEL  = 520     -- panel genişliği
local H_PANEL  = 480     -- panel yüksekliği
local SLIDER_W = 280     -- slider uzunluğu
local SLIDER_H = 4       -- slider yüksekliği
local THUMB_R  = 8       -- sürükleme noktası yarıçapı

local LANGUAGES = {
  { code="tr", label="Türkçe",  flag="TR" },
  { code="en", label="English", flag="EN" },
  { code="ar", label="العربية", flag="AR" },
}

local SECTIONS = { "SES", "DİL", "HAKKINDA" }

-- ─── Konstruktör ─────────────────────────────────────────────────────

function SettingsState.new()
  return setmetatable({}, SettingsState)
end

function SettingsState:enter(data)
  self.fade         = 1
  self.timer        = 0
  self.active_sec   = 1         -- aktif bölüm indeksi
  self.dragging     = nil       -- { key="sfx"|"music", ... }
  self.hover_btn    = nil
  self.dirty        = false     -- ayar değişti mi

  -- Fontlar
  self.f_title   = love.graphics.newFont(26)
  self.f_section = love.graphics.newFont(13)
  self.f_label   = love.graphics.newFont(15)
  self.f_value   = love.graphics.newFont(13)
  self.f_small   = love.graphics.newFont(11)
  self.f_mono    = love.graphics.newFont(11)
  self.f_about   = love.graphics.newFont(14)

  -- Mevcut değerleri yükle
  self.vals = {
    sfx   = SaveSystem.getSetting("sfx",   0.9),
    music = SaveSystem.getSetting("music",  0.7),
    lang  = SaveSystem.getSetting("lang",  "tr"),
  }

  -- Panel konumu (ekran ortası)
  local W, H    = Config.vw(), Config.vh()
  self.panel_x  = W/2 - W_PANEL/2
  self.panel_y  = H/2 - H_PANEL/2

  -- Tüm etkileşim bölgelerini hesapla
  self:_buildLayout()
end

function SettingsState:leave()
  if self.dirty then self:_applySettings() end
end

-- ─── Layout hesabı ───────────────────────────────────────────────────

function SettingsState:_buildLayout()
  local px, py = self.panel_x, self.panel_y

  -- Bölüm sekmeleri (üst)
  self._tabs = {}
  local tab_w  = W_PANEL / #SECTIONS
  for i, sec in ipairs(SECTIONS) do
    table.insert(self._tabs, {
      x = px + (i-1)*tab_w,
      y = py + 50,
      w = tab_w,
      h = 36,
      index = i,
      label = sec,
    })
  end

  -- SES bölümü sliderları
  local sx = px + 120
  local sy = py + 120
  self._sliders = {
    {
      key   = "sfx",
      label = "Ses Efektleri",
      x     = sx,
      y     = sy,
    },
    {
      key   = "music",
      label = "Ambiyans Müzik",
      x     = sx,
      y     = sy + 70,
    },
  }

  -- Dil butonları
  self._lang_btns = {}
  local lbx = px + (W_PANEL - #LANGUAGES * 110) / 2
  for i, lang in ipairs(LANGUAGES) do
    table.insert(self._lang_btns, {
      x     = lbx + (i-1)*115,
      y     = py + 140,
      w     = 105,
      h     = 52,
      code  = lang.code,
      label = lang.label,
      flag  = lang.flag,
    })
  end

  -- Kapat butonu (sağ üst köşe)
  self._close_btn = {
    x = px + W_PANEL - 36,
    y = py + 10,
    w = 26,
    h = 26,
  }

  -- Sıfırla butonu (ses bölümü altı)
  self._reset_btn = {
    x = px + W_PANEL/2 - 60,
    y = py + H_PANEL - 56,
    w = 120,
    h = 32,
    label = "Varsayılan",
  }
end

-- ─── Update ──────────────────────────────────────────────────────────

function SettingsState:update(dt)
  self.timer = self.timer + dt
  if self.fade > 0 then self.fade = math.max(0, self.fade - dt*3) end

  -- Sürükleme devam ediyor mu?
  if self.dragging then
    local mx, _ = Config.toLogical(love.mouse.getPosition())
    self:_updateSlider(self.dragging, mx)
  end

  -- Hover tespiti (butonlar)
  local mx, my = Config.toLogical(love.mouse.getPosition())
  self.hover_btn = nil

  for _, tab in ipairs(self._tabs) do
    if self:_inRect(mx, my, tab) then self.hover_btn = "tab_"..tab.index end
  end
  if self:_inRect(mx, my, self._close_btn) then self.hover_btn = "close" end
  if self.active_sec == 1 then
    if self:_inRect(mx, my, self._reset_btn) then self.hover_btn = "reset" end
  end
  if self.active_sec == 2 then
    for _, lb in ipairs(self._lang_btns) do
      if self:_inRect(mx, my, lb) then self.hover_btn = "lang_"..lb.code end
    end
  end
end

-- ─── Draw ────────────────────────────────────────────────────────────

function SettingsState:draw()
  local W, H = Config.vw(), Config.vh()
  local px, py = self.panel_x, self.panel_y

  -- Arkaplan overlay
  love.graphics.setColor(0, 0, 0, 0.65 * (1 - self.fade))
  love.graphics.rectangle("fill", 0, 0, W, H)

  -- Panel gölgesi
  love.graphics.setColor(0, 0, 0, 0.4 * (1 - self.fade))
  love.graphics.rectangle("fill", px+6, py+6, W_PANEL, H_PANEL, 8)

  -- Panel arka planı
  love.graphics.setColor(0.07, 0.06, 0.05, 0.97 * (1 - self.fade))
  love.graphics.rectangle("fill", px, py, W_PANEL, H_PANEL, 8)

  -- Panel çerçevesi
  love.graphics.setColor(0.28, 0.24, 0.18, 0.7 * (1 - self.fade))
  love.graphics.setLineWidth(0.5)
  love.graphics.rectangle("line", px, py, W_PANEL, H_PANEL, 8)

  -- Başlık çubuğu
  love.graphics.setColor(0.05, 0.04, 0.03, 0.96 * (1 - self.fade))
  love.graphics.rectangle("fill", px, py, W_PANEL, 48, 8)
  love.graphics.setColor(0.05, 0.04, 0.03, 0.96 * (1 - self.fade))
  love.graphics.rectangle("fill", px, py+40, W_PANEL, 8)  -- köşe düzeltme

  love.graphics.setFont(self.f_title)
  love.graphics.setColor(0.82, 0.77, 0.62, 1 - self.fade)
  love.graphics.print("Ayarlar", px + 20, py + 11)

  -- Kapat butonu
  self:_drawCloseBtn(px, py)

  -- Sekme çubuğu
  self:_drawTabs()

  -- Bölüm içeriği
  if self.active_sec == 1 then self:_drawSoundSection()
  elseif self.active_sec == 2 then self:_drawLangSection()
  elseif self.active_sec == 3 then self:_drawAboutSection()
  end

  -- Fade örtüsü
  if self.fade > 0 then
    love.graphics.setColor(0, 0, 0, self.fade)
    love.graphics.rectangle("fill", px, py, W_PANEL, H_PANEL, 8)
  end

  love.graphics.setLineWidth(1)
  love.graphics.setColor(1,1,1,1)
end

function SettingsState:_drawCloseBtn(px, py)
  local btn  = self._close_btn
  local hot  = self.hover_btn == "close"
  love.graphics.setColor(hot and 0.85 or 0.40, 0.38, 0.32, 1)
  love.graphics.setFont(self.f_label)
  love.graphics.print("✕", btn.x + 4, btn.y + 2)
end

function SettingsState:_drawTabs()
  for _, tab in ipairs(self._tabs) do
    local active = tab.index == self.active_sec
    local hot    = self.hover_btn == "tab_"..tab.index

    -- Alt çizgi
    if active then
      love.graphics.setColor(0.75, 0.62, 0.38, 0.9)
      love.graphics.setLineWidth(1.5)
      love.graphics.line(tab.x+8, tab.y+tab.h-1, tab.x+tab.w-8, tab.y+tab.h-1)
    end

    love.graphics.setFont(self.f_section)
    local text_col = active and {0.88, 0.82, 0.65} or
                     (hot    and {0.65, 0.60, 0.48} or {0.40, 0.37, 0.30})
    love.graphics.setColor(text_col[1], text_col[2], text_col[3], 1)
    local tw = self.f_section:getWidth(tab.label)
    love.graphics.print(tab.label, tab.x + tab.w/2 - tw/2, tab.y + 10)
  end
  love.graphics.setLineWidth(1)
end

-- ─── SES Bölümü ──────────────────────────────────────────────────────

function SettingsState:_drawSoundSection()
  local px, py = self.panel_x, self.panel_y
  love.graphics.setFont(self.f_mono)
  love.graphics.setColor(0.35, 0.32, 0.26, 0.7)
  love.graphics.print("// ses seviyeleri", px+20, py+100)

  for _, sl in ipairs(self._sliders) do
    self:_drawSlider(sl)
  end

  -- Sıfırla butonu
  local btn = self._reset_btn
  local hot = self.hover_btn == "reset"
  love.graphics.setColor(0.12, 0.11, 0.09, hot and 0.9 or 0.6)
  love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 5)
  love.graphics.setColor(0.40, 0.36, 0.28, hot and 0.8 or 0.40)
  love.graphics.setLineWidth(0.5)
  love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h, 5)
  love.graphics.setFont(self.f_small)
  love.graphics.setColor(hot and 0.75 or 0.45, 0.42, 0.34, 1)
  local tw = self.f_small:getWidth(btn.label)
  love.graphics.print(btn.label, btn.x + btn.w/2 - tw/2, btn.y + 9)
end

function SettingsState:_drawSlider(sl)
  local val   = self.vals[sl.key]
  local thumb = sl.x + val * SLIDER_W
  local mid_y = sl.y + SLIDER_H/2

  -- Etiket
  love.graphics.setFont(self.f_label)
  love.graphics.setColor(0.72, 0.67, 0.54, 1)
  love.graphics.print(sl.label, self.panel_x + 20, sl.y - 4)

  -- Rel değer (sayısal)
  love.graphics.setFont(self.f_value)
  love.graphics.setColor(0.50, 0.46, 0.36, 0.9)
  local pct = tostring(math.floor(val * 100)) .. "%"
  love.graphics.print(pct, sl.x + SLIDER_W + 14, sl.y - 2)

  -- Slider yolu (arka)
  love.graphics.setColor(0.18, 0.16, 0.13, 1)
  love.graphics.rectangle("fill", sl.x, mid_y - SLIDER_H/2, SLIDER_W, SLIDER_H, 2)

  -- Slider dolu kısım
  love.graphics.setColor(0.72, 0.60, 0.38, 0.85)
  love.graphics.rectangle("fill", sl.x, mid_y - SLIDER_H/2, val*SLIDER_W, SLIDER_H, 2)

  -- Başlangıç/bitiş nokta
  love.graphics.setColor(0.25, 0.22, 0.18, 1)
  love.graphics.circle("fill", sl.x, mid_y, 3)
  love.graphics.circle("fill", sl.x + SLIDER_W, mid_y, 3)

  -- Thumb
  local is_dragging = self.dragging and self.dragging.key == sl.key
  local r = is_dragging and THUMB_R + 2 or THUMB_R
  love.graphics.setColor(0.06, 0.05, 0.04, 1)
  love.graphics.circle("fill", thumb, mid_y, r)
  love.graphics.setColor(0.80, 0.70, 0.48, 1)
  love.graphics.setLineWidth(1.5)
  love.graphics.circle("line", thumb, mid_y, r)
  -- İç dolgu
  love.graphics.setColor(0.72, 0.60, 0.38, is_dragging and 1 or 0.7)
  love.graphics.circle("fill", thumb, mid_y, r - 3)
  love.graphics.setLineWidth(1)
end

-- ─── DİL Bölümü ──────────────────────────────────────────────────────

function SettingsState:_drawLangSection()
  local px, py = self.panel_x, self.panel_y
  love.graphics.setFont(self.f_mono)
  love.graphics.setColor(0.35, 0.32, 0.26, 0.7)
  love.graphics.print("// arayüz dili", px+20, py+100)

  -- RTL uyarısı
  love.graphics.setFont(self.f_small)
  love.graphics.setColor(0.40, 0.37, 0.30, 0.7)
  love.graphics.printf(
    "Arapça (AR) seçildiğinde arayüz sağdan-sola düzene geçer.",
    px+20, py+220, W_PANEL-40, "left"
  )

  -- Dil butonları
  for _, lb in ipairs(self._lang_btns) do
    local active = self.vals.lang == lb.code
    local hot    = self.hover_btn == "lang_"..lb.code

    -- Kutu
    local border_a = active and 0.75 or (hot and 0.40 or 0.18)
    local bg_a     = active and 0.18 or (hot and 0.10 or 0.05)
    local accent   = active and {0.80, 0.68, 0.42} or {0.45, 0.42, 0.34}

    love.graphics.setColor(accent[1], accent[2], accent[3], bg_a)
    love.graphics.rectangle("fill", lb.x, lb.y, lb.w, lb.h, 7)
    love.graphics.setColor(accent[1], accent[2], accent[3], border_a)
    love.graphics.setLineWidth(active and 1.2 or 0.5)
    love.graphics.rectangle("line", lb.x, lb.y, lb.w, lb.h, 7)

    -- Bayrak kodu
    love.graphics.setFont(self.f_section)
    love.graphics.setColor(accent[1], accent[2], accent[3], active and 1 or 0.6)
    local fw = self.f_section:getWidth(lb.flag)
    love.graphics.print(lb.flag, lb.x + lb.w/2 - fw/2, lb.y + 8)

    -- Dil adı
    love.graphics.setFont(self.f_small)
    love.graphics.setColor(active and 0.85 or 0.50,
                           active and 0.80 or 0.47,
                           active and 0.65 or 0.37, 1)
    local lw = self.f_small:getWidth(lb.label)
    love.graphics.print(lb.label, lb.x + lb.w/2 - lw/2, lb.y + 30)

    -- Aktif işaret
    if active then
      love.graphics.setColor(0.80, 0.68, 0.42, 0.9)
      love.graphics.circle("fill", lb.x + lb.w - 10, lb.y + 10, 4)
      love.graphics.setColor(0.05, 0.04, 0.03, 1)
      love.graphics.setFont(self.f_small)
      love.graphics.print("✓", lb.x + lb.w - 13, lb.y + 4)
    end
  end

  love.graphics.setLineWidth(1)
end

-- ─── HAKKINDA Bölümü ─────────────────────────────────────────────────

function SettingsState:_drawAboutSection()
  local px, py = self.panel_x, self.panel_y

  love.graphics.setFont(self.f_mono)
  love.graphics.setColor(0.35, 0.32, 0.26, 0.7)
  love.graphics.print("// proje hakkında", px+20, py+100)

  local lines = {
    { text="HİCRET",     font=self.f_title,   color={0.85, 0.80, 0.65} },
    { text="",           font=self.f_about,   color={0.0, 0.0, 0.0}    },
    { text="Tür: Anlatı & Hayatta Kalma",
                         font=self.f_about,   color={0.60, 0.56, 0.44} },
    { text="Motor: LÖVE 2D 11.x (Lua)",
                         font=self.f_about,   color={0.60, 0.56, 0.44} },
    { text="Platform: Android · iOS · Web",
                         font=self.f_about,   color={0.60, 0.56, 0.44} },
    { text="",           font=self.f_about,   color={0.0, 0.0, 0.0}    },
    { text="DUT Interdisciplinary Design Agency",
                         font=self.f_about,   color={0.50, 0.47, 0.37} },
    { text="",           font=self.f_about,   color={0.0, 0.0, 0.0}    },
    { text="v0.3 — Ses Sistemi",
                         font=self.f_small,   color={0.35, 0.32, 0.26} },
  }

  local y = py + 128
  for _, ln in ipairs(lines) do
    if ln.text ~= "" then
      love.graphics.setFont(ln.font)
      love.graphics.setColor(ln.color[1], ln.color[2], ln.color[3], 1)
      love.graphics.print(ln.text, px+20, y)
      y = y + ln.font:getHeight() + 4
    else
      y = y + 10
    end
  end

  -- Alt: etik notu
  love.graphics.setFont(self.f_small)
  love.graphics.setColor(0.30, 0.28, 0.22, 0.75)
  love.graphics.printf(
    '"Haber programları istatistik verir;\n oyun ise sorumluluk yükler."',
    px + 20, py + H_PANEL - 80, W_PANEL - 40, "left"
  )
end

-- ─── Girdi ───────────────────────────────────────────────────────────

function SettingsState:mousepressed(x, y, btn)
  if btn ~= 1 then return end
  self:_handlePress(x, y)
end

function SettingsState:touchpressed(id, x, y, p)
  self:_handlePress(x, y)
end

function SettingsState:mousereleased(x, y, btn)
  if self.dragging then
    self:_updateSlider(self.dragging, x)
    self:_applySettings()
    self.dragging = nil
  end
end

function SettingsState:touchreleased(id, x, y, p)
  if self.dragging then
    self:_updateSlider(self.dragging, x)
    self:_applySettings()
    self.dragging = nil
  end
end

function SettingsState:touchmoved(id, x, y, dx, dy, p)
  if self.dragging then self:_updateSlider(self.dragging, x) end
end

function SettingsState:_handlePress(x, y)
  -- Kapat
  if self:_inRect(x, y, self._close_btn) then
    StateManager.pop()
    return
  end

  -- Sekme
  for _, tab in ipairs(self._tabs) do
    if self:_inRect(x, y, tab) then
      self.active_sec = tab.index
      return
    end
  end

  -- Slider başlatma
  if self.active_sec == 1 then
    for _, sl in ipairs(self._sliders) do
      local mid_y = sl.y + SLIDER_H/2
      if math.abs(y - mid_y) <= THUMB_R + 4 and
         x >= sl.x - THUMB_R and x <= sl.x + SLIDER_W + THUMB_R then
        self.dragging = sl
        self:_updateSlider(sl, x)
        return
      end
    end
    -- Sıfırla butonu
    if self:_inRect(x, y, self._reset_btn) then
      self.vals.sfx   = 0.9
      self.vals.music = 0.7
      self:_applySettings()
      return
    end
  end

  -- Dil seçimi
  if self.active_sec == 2 then
    for _, lb in ipairs(self._lang_btns) do
      if self:_inRect(x, y, lb) then
        self.vals.lang = lb.code
        SaveSystem.setSetting("lang", lb.code)
        I18n.init(lb.code)
        self.dirty = false   -- hemen uygulandı
        return
      end
    end
  end

  -- Panel dışı tıklama → kapat
  local px, py = self.panel_x, self.panel_y
  if x < px or x > px+W_PANEL or y < py or y > py+H_PANEL then
    StateManager.pop()
  end
end

function SettingsState:keypressed(key)
  if key == "escape" then StateManager.pop() end

  -- Klavye ile slider kontrolü
  if self.active_sec == 1 then
    local step = 0.05
    local focused = self._sliders[self._focused_slider or 1]
    if key == "left"  then self.vals[focused.key] = math.max(0, self.vals[focused.key] - step) end
    if key == "right" then self.vals[focused.key] = math.min(1, self.vals[focused.key] + step) end
    if key == "tab"   then
      self._focused_slider = ((self._focused_slider or 1) % #self._sliders) + 1
    end
    if key == "left" or key == "right" then self:_applySettings() end
  end
end

-- ─── Yardımcılar ─────────────────────────────────────────────────────

function SettingsState:_updateSlider(sl, mx)
  local rel = (mx - sl.x) / SLIDER_W
  self.vals[sl.key] = math.max(0, math.min(1, rel))
  self.dirty = true
  -- Anlık ses geri bildirimi
  AudioManager.setVolume(sl.key == "sfx" and "sfx" or "ambient", self.vals[sl.key])
end

function SettingsState:_applySettings()
  AudioManager.setVolume("sfx",     self.vals.sfx)
  AudioManager.setVolume("ambient", self.vals.music)
  SaveSystem.setSetting("lang",     self.vals.lang)
  self.dirty = false
end

function SettingsState:_inRect(x, y, r)
  return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function SettingsState:touchmoved(id, x, y, dx, dy, p)
  if self.dragging then self:_updateSlider(self.dragging, x) end
end

return SettingsState
