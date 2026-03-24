--[[
  MapCamera — Kaydırma & Yakınlaştırma Kamerası
  
  Pan, pinch-zoom ve mouse wheel zoom destekler.
  Sınır kontrolü: içerik viewport dışına taşmaz.
  Momentum (fling) ile parmak bırakıldıktan sonra kayma devam eder.
  
  Kullanım:
    local cam = MapCamera.new(content_w, content_h, view_w, view_h)
    
    -- Update'de:
    cam:update(dt, touch_manager)
    
    -- Çizim öncesi:
    cam:push()   -- love.graphics.push + translate + scale
    -- ... içeriği çiz ...
    cam:pop()
    
    -- Koordinat dönüşümü:
    local cx, cy = cam:toContent(screen_x, screen_y)
    local sx, sy = cam:toScreen(content_x, content_y)
--]]

local MapCamera = {}
MapCamera.__index = MapCamera

local ZOOM_MIN  = 0.50   -- min zoom seviyesi (içerik küçülür)
local ZOOM_MAX  = 3.50   -- max zoom seviyesi
local ZOOM_STEP = 0.12   -- mouse wheel adım

-- Momentum sabitleri
local FLING_DAMP  = 0.88   -- frame başı hız sönüm katsayısı
local FLING_STOP  = 0.8    -- px/sn altında durdur

-- Pinch smoothing
local PINCH_SMOOTH = 0.35

function MapCamera.new(content_w, content_h, view_w, view_h)
  local self = setmetatable({}, MapCamera)

  self.content_w = content_w
  self.content_h = content_h
  self.view_w    = view_w
  self.view_h    = view_h

  -- Başlangıç zoom: içeriği tam sığdır
  local fit_x = view_w / content_w
  local fit_y = view_h / content_h
  self.zoom    = math.min(fit_x, fit_y)
  self.zoom    = math.max(ZOOM_MIN, math.min(ZOOM_MAX, self.zoom))

  -- Pan: viewport içinde içeriğin sol üst köşesi
  self.ox = 0   -- content x offset (negatif = sağa kaydırılmış)
  self.oy = 0
  self:_clamp()

  -- Momentum
  self.vx = 0
  self.vy = 0

  -- Pinch
  self._pinch_zoom_target = self.zoom

  return self
end

-- ─── Update ──────────────────────────────────────────────────────────

function MapCamera:update(dt, touch_manager)
  if touch_manager then
    self:_handleTouch(dt, touch_manager)
  end
  self:_applyMomentum(dt)
  self:_clamp()
end

function MapCamera:_handleTouch(dt, TM)
  -- Pinch zoom
  local pinch = TM.getPinch()
  if pinch.active and pinch.scale ~= 1.0 then
    -- Pinch merkezini içerik koordinatına çevir
    local cx, cy = self:toContent(pinch.cx, pinch.cy)

    -- Yeni zoom hesapla
    local new_zoom = self.zoom * pinch.scale
    new_zoom = math.max(ZOOM_MIN, math.min(ZOOM_MAX, new_zoom))

    -- Zoom noktası etrafında kaydır (zoom merkezini sabitle)
    -- İçerik noktası cx,cy ekran üzerinde aynı yerde kalmalı
    local old_sx = cx * self.zoom + self.ox
    local old_sy = cy * self.zoom + self.oy
    self.zoom = new_zoom
    self.ox   = old_sx - cx * self.zoom
    self.oy   = old_sy - cy * self.zoom

    -- Pinch hareketi sırasında momentum sıfırla
    self.vx, self.vy = 0, 0
  end

  -- Pan (tek parmak sürükleme)
  local pan = TM.getPan()
  if pan.active then
    self.ox = self.ox + pan.dx
    self.oy = self.oy + pan.dy
    self.vx, self.vy = 0, 0
  end

  -- Fling (parmak bırakıldı, momentum devam ediyor)
  local fling = TM.getFling()
  if fling.active and not pan.active then
    self.vx = fling.vx
    self.vy = fling.vy
  end
end

function MapCamera:_applyMomentum(dt)
  if math.abs(self.vx) > FLING_STOP or math.abs(self.vy) > FLING_STOP then
    self.ox = self.ox + self.vx * dt
    self.oy = self.oy + self.vy * dt
    self.vx = self.vx * FLING_DAMP
    self.vy = self.vy * FLING_DAMP
  else
    self.vx, self.vy = 0, 0
  end
end

-- ─── Mouse wheel zoom ─────────────────────────────────────────────────

function MapCamera:wheelzoom(mx, my, dy)
  local cx, cy = self:toContent(mx, my)
  local new_zoom = self.zoom * (dy > 0 and (1 + ZOOM_STEP) or (1 - ZOOM_STEP))
  new_zoom = math.max(ZOOM_MIN, math.min(ZOOM_MAX, new_zoom))

  local old_sx = cx * self.zoom + self.ox
  local old_sy = cy * self.zoom + self.oy
  self.zoom = new_zoom
  self.ox   = old_sx - cx * self.zoom
  self.oy   = old_sy - cy * self.zoom
  self:_clamp()
end

-- ─── Sınır kontrolü ──────────────────────────────────────────────────

function MapCamera:_clamp()
  local cw = self.content_w * self.zoom
  local ch = self.content_h * self.zoom

  -- İçerik ekrandan küçükse ortala
  if cw <= self.view_w then
    self.ox = (self.view_w - cw) / 2
  else
    self.ox = math.max(self.view_w - cw, math.min(0, self.ox))
  end

  if ch <= self.view_h then
    self.oy = (self.view_h - ch) / 2
  else
    self.oy = math.max(self.view_h - ch, math.min(0, self.oy))
  end
end

-- ─── Koordinat dönüşümü ───────────────────────────────────────────────

--- Ekran (view) koordinatını içerik koordinatına çevirir
function MapCamera:toContent(sx, sy)
  return (sx - self.ox) / self.zoom,
         (sy - self.oy) / self.zoom
end

--- İçerik koordinatını ekran koordinatına çevirir
function MapCamera:toScreen(cx, cy)
  return cx * self.zoom + self.ox,
         cy * self.zoom + self.oy
end

-- ─── Çizim ───────────────────────────────────────────────────────────

function MapCamera:push()
  love.graphics.push()
  love.graphics.translate(self.ox, self.oy)
  love.graphics.scale(self.zoom, self.zoom)
end

function MapCamera:pop()
  love.graphics.pop()
end

--- Viewport boyutunu güncelle (pencere yeniden boyutlandığında)
function MapCamera:setViewSize(w, h)
  self.view_w = w
  self.view_h = h
  self:_clamp()
end

--- Belirli içerik noktasını ortaya al (animasyonsuz)
function MapCamera:centerOn(cx, cy)
  self.ox = self.view_w/2 - cx * self.zoom
  self.oy = self.view_h/2 - cy * self.zoom
  self:_clamp()
end

--- Zoom bilgisi
function MapCamera:getZoom() return self.zoom end
function MapCamera:getOffset() return self.ox, self.oy end

--- Fit-to-view sıfırla
function MapCamera:reset()
  local fit_x = self.view_w / self.content_w
  local fit_y = self.view_h / self.content_h
  self.zoom = math.max(ZOOM_MIN, math.min(ZOOM_MAX, math.min(fit_x, fit_y)))
  self.ox, self.oy = 0, 0
  self.vx, self.vy = 0, 0
  self:_clamp()
end

return MapCamera
