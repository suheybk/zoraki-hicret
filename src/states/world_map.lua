--[[
  WorldMapState — Dünya Haritası
  Pan + Pinch-Zoom + Swipe + Double-Tap-To-Region
  MapCamera + TouchManager entegrasyonu
--]]

local StateManager  = require("src.systems.state_manager")
local SaveSystem    = require("src.systems.save_system")
local I18n          = require("src.systems.i18n")
local Config        = require("src.utils.config")
local MapRenderer   = require("src.ui.map_renderer")
local AudioManager  = require("src.systems.audio_manager")
local TouchManager  = require("src.systems.touch_manager")
local MapCamera     = require("src.systems.map_camera")

local WorldMapState = {}
WorldMapState.__index = WorldMapState

-- Kıta haritası 1280×720 sanal boyutu
local CONTENT_W, CONTENT_H = 1280, 720

local REGION_DEFS = {
  { id="gaza",     lon=34.5, lat=31.5, color={0.88,0.30,0.22}, tag="occ"   },
  { id="uyghur",   lon=85.0, lat=42.0, color={0.12,0.72,0.52}, tag="auth"  },
  { id="rohingya", lon=93.0, lat=20.0, color={0.94,0.62,0.15}, tag="eth"   },
  { id="syria",    lon=38.5, lat=35.0, color={0.28,0.58,0.90}, tag="war"   },
  { id="yemen",    lon=48.0, lat=15.5, color={0.83,0.35,0.52}, tag="proxy" },
  { id="kashmir",  lon=76.0, lat=34.0, color={0.55,0.50,0.92}, tag="occ"   },
}

local DOT_R  = 7
local HIT_R  = 22     -- dokunmatik isabet alanı

function WorldMapState.new()
  return setmetatable({}, WorldMapState)
end

function WorldMapState:enter(data)
  MapRenderer.init()
  AudioManager.setRegion("map")

  local W, H = Config.vw(), Config.vh()

  -- Kamera: harita CONTENT_W×CONTENT_H, görüntü W×H
  -- Üst çubuk (48px) ve alt lejant için görüntü daraltılmış
  local VIEW_Y = 48
  local VIEW_H = H - VIEW_Y
  self.cam = MapCamera.new(CONTENT_W, CONTENT_H, W, VIEW_H)
  self.cam.view_offset_y = VIEW_Y   -- çizimde üstten kaydırma
  self.cam:reset()

  -- Bölge noktaları (lon/lat → içerik koordinatı)
  self.regions = {}
  for i, def in ipairs(REGION_DEFS) do
    local r = {}
    for k, v in pairs(def) do r[k] = v end
    r._phase = (i-1) * (math.pi*2 / #REGION_DEFS)
    -- MapRenderer projeksiyon: içerik koordinatı
    r.cx, r.cy = MapRenderer.project(def.lon, def.lat)
    table.insert(self.regions, r)
  end

  self.timer    = 0
  self.hovered  = nil
  self.fade     = 1
  self._tooltip_alpha  = 0
  self._tooltip_region = nil
  self._prev_hovered   = nil

  -- Zoom göstergesi
  self._zoom_hint_t = 0   -- ne zaman son zoom oldu
  self._zoom_val    = 1.0

  -- Bağlantı çizgileri
  self._conn_lines = self:_buildConnLines()

  self.font_title   = love.graphics.newFont(22)
  self.font_ui      = love.graphics.newFont(13)
  self.font_small   = love.graphics.newFont(10)
  self.font_tt_name = love.graphics.newFont(14)
  self.font_tt_body = love.graphics.newFont(12)
  self.font_zoom    = love.graphics.newFont(11)
end

function WorldMapState:_buildConnLines()
  local links = {
    {"gaza","syria"},{"syria","yemen"},
    {"gaza","kashmir"},{"kashmir","uyghur"},{"uyghur","rohingya"},
  }
  local res = {}
  for _, lk in ipairs(links) do
    local a, b = nil, nil
    for _, r in ipairs(self.regions) do
      if r.id == lk[1] then a = r end
      if r.id == lk[2] then b = r end
    end
    if a and b then table.insert(res, {ax=a.cx,ay=a.cy,bx=b.cx,by=b.cy}) end
  end
  return res
end

-- ─── Update ──────────────────────────────────────────────────────────

function WorldMapState:update(dt)
  self.timer = self.timer + dt
  if self.fade > 0 then self.fade = math.max(0, self.fade - dt*1.8) end

  -- Kamerayı güncelle (touch gesture'ları işler)
  local W, H = Config.vw(), Config.vh()
  self.cam:setViewSize(W, H - 48)
  self.cam:update(dt, TouchManager)

  -- Zoom değeri gösterge
  if self._zoom_val ~= self.cam:getZoom() then
    self._zoom_val  = self.cam:getZoom()
    self._zoom_hint_t = self.timer
  end

  -- Hover (fare — kamera koordinatına çevir)
  local mx, my = Config.toLogical(love.mouse.getPosition())
  local prev_hovered = self.hovered
  self.hovered = self:_hitTest(mx, my)

  if self.hovered ~= prev_hovered and self.hovered ~= nil then
    AudioManager.playSFX("map_hover", 0.40)
  end

  if self.hovered then
    self._tooltip_alpha  = math.min(1, self._tooltip_alpha + dt*5)
    self._tooltip_region = self.hovered
  else
    self._tooltip_alpha  = math.max(0, self._tooltip_alpha - dt*4)
  end

  -- TouchManager gesture tüketimi
  local tap = TouchManager.consumeTap()
  if tap then self:_trySelect(tap.x, tap.y) end

  local dtap = TouchManager.consumeDoubleTap()
  if dtap then self:_doubleTapZoom(dtap.x, dtap.y) end

  local swipe = TouchManager.consumeSwipe()
  if swipe then self:_handleSwipe(swipe) end

  local lp = TouchManager.consumeLongPress()
  if lp then self:_handleLongPress(lp.x, lp.y) end
end

-- ─── Koordinat yardımcıları ───────────────────────────────────────────

--- Ekran koordinatını içerik koordinatına çevir (kamera dikkate alarak)
function WorldMapState:_screenToContent(sx, sy)
  -- Üst çubuk offseti
  return self.cam:toContent(sx, sy - 48)
end

--- Bölge isabet testi
function WorldMapState:_hitTest(sx, sy)
  local cx, cy = self:_screenToContent(sx, sy)
  for _, r in ipairs(self.regions) do
    if SaveSystem.isUnlocked(r.id) then
      -- Zoom'a göre isabet alanı ölçekle (küçük zoom'da daha büyük isabet)
      local hit = HIT_R / self.cam:getZoom()
      local dx, dy = cx - r.cx, cy - r.cy
      if dx*dx + dy*dy <= hit*hit then return r.id end
    end
  end
  return nil
end

-- ─── Gesture Handlers ────────────────────────────────────────────────

function WorldMapState:_trySelect(sx, sy)
  local hit = self:_hitTest(sx, sy)
  if hit then
    AudioManager.playSFX("map_select", 0.8)
    AudioManager.stopAmbient()
    I18n.loadChapter(hit)
    StateManager.switch("chapter", {chapter_id=hit})
  end
end

function WorldMapState:_doubleTapZoom(sx, sy)
  -- Double-tap: bölgeye yakınlaştır veya sıfırla
  local cx, cy = self:_screenToContent(sx, sy)
  local cur_zoom = self.cam:getZoom()
  if cur_zoom > 1.5 then
    self.cam:reset()
  else
    -- 2.5x zoom, dokunulan içerik noktasını merkeze al
    self.cam.zoom = math.min(2.5, self.cam.zoom * 2)
    self.cam:centerOn(cx, cy)
  end
end

function WorldMapState:_handleSwipe(sw)
  -- Swipe navigasyonu: sol/sağ → bir sonraki/önceki bölge
  -- Yukarı/aşağı → zoom in/out
  if sw.dir == "up" and math.abs(sw.vy) > math.abs(sw.vx) then
    self.cam.zoom = math.min(3.5, self.cam.zoom * 1.3)
    self.cam:_clamp()
  elseif sw.dir == "down" and math.abs(sw.vy) > math.abs(sw.vx) then
    self.cam.zoom = math.max(0.5, self.cam.zoom * 0.77)
    self.cam:_clamp()
  end
end

function WorldMapState:_handleLongPress(sx, sy)
  -- Long press: bölge üzerindeyse tooltip sabitler, değilse kamerayı sıfırlar
  local hit = self:_hitTest(sx, sy)
  if not hit then
    self.cam:reset()
  end
end

-- ─── Draw ────────────────────────────────────────────────────────────

function WorldMapState:draw()
  local W, H = Config.vw(), Config.vh()

  love.graphics.setColor(0.05, 0.04, 0.03, 1)
  love.graphics.rectangle("fill", 0, 0, W, H)

  -- Harita kamera alanı (üst çubuk altından başlar)
  love.graphics.setScissor(0, 48, W, H-48)  -- kırpma (taşma önleme)

  love.graphics.push()
  love.graphics.translate(0, 48)   -- üst çubuk boşluğu
  self.cam:push()

  -- ① Harita arka planı
  MapRenderer.draw(self.timer)

  -- ② Bağlantı çizgileri
  love.graphics.setColor(0.45, 0.38, 0.25, 0.12)
  love.graphics.setLineWidth(0.5 / self.cam:getZoom())
  for _, ln in ipairs(self._conn_lines) do
    love.graphics.line(ln.ax, ln.ay, ln.bx, ln.by)
  end

  -- ③ Kriz noktaları
  for _, r in ipairs(self.regions) do
    self:_drawDot(r)
  end

  self.cam:pop()
  love.graphics.pop()

  love.graphics.setScissor()  -- kırpmayı kaldır

  -- ④ Üst çubuk (kamera dışı, sabit)
  self:_drawTopBar(W)

  -- ⑤ Lejant (sabit)
  self:_drawLegend(W, H)

  -- ⑥ Tooltip (sabit, kamera koordinatından çevrilmiş)
  if self._tooltip_alpha > 0.01 and self._tooltip_region then
    self:_drawTooltip(self._tooltip_region, W, H)
  end

  -- ⑦ Zoom göstergesi
  self:_drawZoomIndicator(W, H)

  -- ⑧ Dokunmatik ipuçları (sadece touch cihazda)
  self:_drawTouchHints(W, H)

  -- ⑨ Fade
  if self.fade > 0 then
    love.graphics.setColor(0, 0, 0, self.fade)
    love.graphics.rectangle("fill", 0, 0, W, H)
  end
  love.graphics.setColor(1,1,1,1)
  love.graphics.setLineWidth(1)
end

function WorldMapState:_drawDot(r)
  local unlocked  = SaveSystem.isUnlocked(r.id)
  local completed = SaveSystem.isCompleted(r.id)
  local cr,cg,cb  = r.color[1], r.color[2], r.color[3]
  local t = self.timer

  -- Zoom'a göre düğüm boyutunu ters ölçekle
  -- (zoom arttıkça düğüm sabit görünür boyutta kalır)
  local zoom = self.cam:getZoom()
  local r_base = DOT_R / zoom
  local PULSE_MAX = 18 / zoom

  if not unlocked then
    love.graphics.setColor(0.18, 0.16, 0.14, 0.5)
    love.graphics.circle("fill", r.cx, r.cy, r_base*0.5)
    return
  end

  local is_hover = self.hovered == r.id

  -- Pulse
  for wave = 1, 2 do
    local phase = t*2.0 + r._phase + wave*0.8
    local progress = (math.sin(phase)+1)/2
    local pr = r_base + progress*(PULSE_MAX - r_base)*(wave==1 and 1 or 0.6)
    love.graphics.setColor(cr,cg,cb, (1-progress)*(wave==1 and 0.22 or 0.12))
    love.graphics.circle("fill", r.cx, r.cy, pr)
  end

  love.graphics.setColor(cr,cg,cb, is_hover and 0.8 or 0.35)
  love.graphics.setLineWidth((is_hover and 1.2 or 0.6) / zoom)
  love.graphics.circle("line", r.cx, r.cy, r_base+(is_hover and 5 or 3)/zoom)

  love.graphics.setColor(cr,cg,cb, completed and 0.65 or 1.0)
  love.graphics.circle("fill", r.cx, r.cy, r_base)
  love.graphics.setColor(1,1,1,0.25)
  love.graphics.circle("fill", r.cx-r_base*0.25, r.cy-r_base*0.25, r_base*0.35)

  if completed then
    love.graphics.setColor(1,1,1,0.85)
    love.graphics.setLineWidth(1.5/zoom)
    love.graphics.line(r.cx-3/zoom, r.cy, r.cx-1/zoom, r.cy+3/zoom, r.cx+4/zoom, r.cy-3/zoom)
  end

  if not is_hover then
    love.graphics.setFont(self.font_small)
    local label = I18n.t("region."..r.id..".short")
    if label:sub(1,1)=="[" then label = r.id end
    local scale = 1/zoom
    love.graphics.push()
    love.graphics.translate(r.cx + r_base + 2/zoom, r.cy - 5/zoom)
    love.graphics.scale(scale, scale)
    love.graphics.setColor(cr,cg,cb, 0.75)
    love.graphics.print(label, 0, 0)
    love.graphics.pop()
  end
  love.graphics.setLineWidth(1)
end

function WorldMapState:_drawTopBar(W)
  love.graphics.setColor(0.04, 0.03, 0.03, 0.92)
  love.graphics.rectangle("fill", 0, 0, W, 52)
  love.graphics.setColor(0.25, 0.22, 0.16, 0.5)
  love.graphics.setLineWidth(0.5)
  love.graphics.line(0, 52, W, 52)

  -- Sol: Ana Menü geri butonu
  love.graphics.setFont(self.font_small)
  love.graphics.setColor(0.48, 0.44, 0.35, 0.85)
  love.graphics.print("← Ana Menü", 16, 8)

  -- Orta: Başlık
  love.graphics.setFont(self.font_title)
  love.graphics.setColor(0.85, 0.80, 0.65, 1)
  local tw = self.font_title:getWidth("HİCRET")
  love.graphics.print("HİCRET", W/2 - tw/2, 6)

  -- Orta alt: ipucu
  love.graphics.setFont(self.font_small)
  love.graphics.setColor(0.38, 0.35, 0.27, 0.65)
  local hint = "Bir bölgeye tıkla"
  love.graphics.print(hint, W/2 - self.font_small:getWidth(hint)/2, 34)

  -- Sağ: kısayollar
  love.graphics.setColor(0.32, 0.29, 0.23, 0.75)
  love.graphics.print("[ S ] Ayarlar  [ A ] Arşiv  [ R ] Sıfırla", W - 278, 19)

  love.graphics.setLineWidth(1)
end

function WorldMapState:_drawLegend(W, H)
  local entries = {
    {label="İşgal",          color={0.88,0.30,0.22}},
    {label="Otoriter Baskı", color={0.12,0.72,0.52}},
    {label="Etnik Kıyım",    color={0.94,0.62,0.15}},
    {label="Savaş",          color={0.28,0.58,0.90}},
    {label="Vekâlet Savaşı", color={0.83,0.35,0.52}},
  }
  local lx, ly = 24, H - 10 - #entries*15
  love.graphics.setColor(0.04, 0.03, 0.03, 0.75)
  love.graphics.rectangle("fill", lx-6, ly-6, 148, #entries*15+12, 4)
  love.graphics.setFont(self.font_small)
  for i, e in ipairs(entries) do
    local y = ly + (i-1)*15
    love.graphics.setColor(e.color[1],e.color[2],e.color[3],0.9)
    love.graphics.circle("fill", lx+4, y+5, 4)
    love.graphics.setColor(0.60,0.57,0.48,0.9)
    love.graphics.print(e.label, lx+14, y)
  end
end

function WorldMapState:_drawTooltip(region_id, W, H)
  local r
  for _, reg in ipairs(self.regions) do
    if reg.id == region_id then r = reg; break end
  end
  if not r then return end

  -- Bölge noktasını ekran koordinatına çevir
  local sx, sy = self.cam:toScreen(r.cx, r.cy)
  sy = sy + 48  -- üst çubuk ofseti

  local cr,cg,cb = r.color[1],r.color[2],r.color[3]
  local alpha    = self._tooltip_alpha

  local name = I18n.t("region."..r.id..".name")
  if name:sub(1,1)=="[" then name = r.id end
  local desc = I18n.t("region."..r.id..".desc")
  if desc:sub(1,1)=="[" then desc="" end
  local action = SaveSystem.isCompleted(r.id) and "✓ Tamamlandı" or "Başlamak için dokun"

  local tw, th = 230, 88
  local tx = sx + 14
  if tx+tw > W-20 then tx = sx - tw - 14 end
  local ty = math.max(56, math.min(sy-20, H-60-th))

  love.graphics.setColor(0.06,0.05,0.04, 0.94*alpha)
  love.graphics.rectangle("fill", tx, ty, tw, th, 5)
  love.graphics.setColor(cr,cg,cb, 0.75*alpha)
  love.graphics.rectangle("fill", tx, ty, 3, th, 2)
  love.graphics.setColor(cr,cg,cb, 0.25*alpha)
  love.graphics.setLineWidth(0.5)
  love.graphics.rectangle("line", tx, ty, tw, th, 5)

  love.graphics.setFont(self.font_tt_name)
  love.graphics.setColor(0.90,0.85,0.72, alpha)
  love.graphics.print(name, tx+10, ty+10)

  love.graphics.setFont(self.font_tt_body)
  love.graphics.setColor(0.60,0.56,0.46, 0.9*alpha)
  love.graphics.printf(desc, tx+10, ty+30, tw-18, "left")

  love.graphics.setFont(self.font_small)
  love.graphics.setColor(cr,cg,cb, 0.7*alpha)
  love.graphics.print(action, tx+10, ty+th-16)
  love.graphics.setLineWidth(1)
end

function WorldMapState:_drawZoomIndicator(W, H)
  local t_since = self.timer - self._zoom_hint_t
  if t_since > 2.0 then return end  -- 2sn sonra gizle
  local alpha   = math.max(0, 1 - (t_since - 1.2) / 0.8)
  local pct     = math.floor(self.cam:getZoom() * 100)
  local label   = pct .. "%"
  love.graphics.setFont(self.font_zoom)
  love.graphics.setColor(0.72, 0.65, 0.48, alpha * 0.85)
  love.graphics.print("⊕ " .. label, W/2 - 24, H - 30)
end

function WorldMapState:_drawTouchHints(W, H)
  -- Sadece ilk 5 saniyede, sadece dokunmatik için
  if self.timer > 5 then return end
  local alpha = math.max(0, 1 - self.timer / 4.0) * 0.55
  love.graphics.setFont(self.font_small)
  love.graphics.setColor(0.55, 0.52, 0.42, alpha)
  love.graphics.printf("İki parmakla yakınlaştır  •  Swipe'la kaydır  •  Çift dokun: zoom", 0, H - 54, W, "center")
end

-- ─── Girdi ───────────────────────────────────────────────────────────

function WorldMapState:mousepressed(x, y, btn)
  if btn == 1 then
    -- Sol üst "Ana Menü" butonu tıklaması
    if x < 130 and y < 52 then
      StateManager.switch("menu"); return
    end
    self:_trySelect(x, y)
  end
end

function WorldMapState:wheelmoved(mx, my, dy)
  self.cam:wheelzoom(mx, my - 48, dy)
  self._zoom_hint_t = self.timer
end

function WorldMapState:mousemoved(mx, my, dx, dy)
  -- Mouse drag pan (orta tuş veya sağ tuş)
  if love.mouse.isDown(2) or love.mouse.isDown(3) then
    self.cam.ox = self.cam.ox + dx
    self.cam.oy = self.cam.oy + dy
    self.cam:_clamp()
  end
end

-- Touch olaylarını TouchManager'a ilet (main.lua üzerinden gelir)
function WorldMapState:touchpressed(id, x, y, p)  end
function WorldMapState:touchreleased(id, x, y, p) end
function WorldMapState:touchmoved(id, x, y, dx, dy, p) end

function WorldMapState:keypressed(key)
  if key == "escape" then StateManager.switch("menu") end
  if key == "a" then StateManager.switch("archive") end
  if key == "s" or key == "," then StateManager.push("settings") end
  if key == "r" then self.cam:reset(); self._zoom_hint_t = self.timer end
  if key == "u" and love.keyboard.isDown("lctrl") then
    for _, r in ipairs(self.regions) do SaveSystem.unlockChapter(r.id) end
    print("[DEBUG] Tüm bölgeler açıldı")
  end
end

return WorldMapState
