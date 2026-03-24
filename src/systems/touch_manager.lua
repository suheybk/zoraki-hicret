--[[
  TouchManager — Çok Dokunuşlu Hareket Tanıyıcı
  
  Desteklenen hareketler:
    TAP          — kısa dokunma (≤200ms, ≤12px hareket)
    DOUBLE_TAP   — 300ms içinde iki kez tap
    LONG_PRESS   — 500ms hareketsiz basma
    SWIPE        — hızlı tek parmak kayma (yön + hız)
    PAN          — yavaş tek parmak sürükleme (sürekli delta)
    PINCH        — iki parmak yaklaştır/uzaklaştır (scale delta)
    ROTATE       — iki parmak döndürme (açı delta)
  
  Kullanım (state içinde):
    local TouchManager = require("src.systems.touch_manager")
    
    -- Olayları yakala:
    function State:touchpressed(id,x,y,p)  TouchManager.pressed(id,x,y) end
    function State:touchreleased(id,x,y,p) TouchManager.released(id,x,y) end
    function State:touchmoved(id,x,y,dx,dy,p) TouchManager.moved(id,x,y,dx,dy) end
    
    -- Hareketleri oku:
    function State:update(dt)
      TouchManager.update(dt)
      
      local tap = TouchManager.consumeTap()
      if tap then ... end
      
      local pan = TouchManager.getPan()
      if pan.active then ... end
      
      local pinch = TouchManager.getPinch()
      if pinch.active then
        local scale_delta = pinch.scale   -- 1.0 = değişmedi, 1.1 = %10 büyüdü
        local cx, cy = pinch.cx, pinch.cy -- iki parmak merkezi
      end
    end
  
  NOT: Koordinatlar Config.toLogical() geçirilmiş sanal koordinat olmalı.
       main.lua'daki touch callback'leri zaten dönüştürüyor.
--]]

local TouchManager = {}

-- ─── Sabitler ────────────────────────────────────────────────────────

local TAP_MAX_DUR   = 0.22    -- sn: tap olarak sayılacak max süre
local TAP_MAX_MOVE  = 14      -- px: tap için max hareket
local DOUBLE_TAP_DT = 0.32    -- sn: iki tap arasındaki max süre
local LONG_PRESS_DT = 0.52    -- sn: long press için min süre
local SWIPE_MIN_V   = 300     -- px/sn: swipe minimum hız
local SWIPE_MIN_D   = 40      -- px: swipe minimum mesafe
local PAN_MIN_D     = 6       -- px: pan başlamak için min hareket

-- ─── Dahili durum ─────────────────────────────────────────────────────

local _touches     = {}   -- id → { x,y, ox,oy, dx,dy, t, moved }
local _touch_count = 0

-- Kuyruklar (consume ile boşaltılır)
local _tap_queue        = {}   -- { x, y }
local _double_tap_queue = {}   -- { x, y }
local _long_press_queue = {}   -- { x, y }
local _swipe_queue      = {}   -- { x, y, dir, vx, vy }

-- Pan durumu (sürekli)
local _pan = { active=false, x=0, y=0, dx=0, dy=0, vx=0, vy=0 }

-- Pinch durumu (sürekli)
local _pinch = { active=false, scale=1.0, cx=0, cy=0, angle=0, angle_delta=0 }

-- Son tap zamanı (double-tap tespiti için)
local _last_tap = { t=-999, x=0, y=0 }

-- Long press takip
local _long_candidate = nil   -- { id, x, y, t }

-- Pan takip
local _pan_id = nil   -- pan yapan parmak ID'si

-- ─── Yardımcılar ─────────────────────────────────────────────────────

local function _dist(ax, ay, bx, by)
  local dx, dy = bx-ax, by-ay
  return math.sqrt(dx*dx + dy*dy)
end

local function _angle(ax, ay, bx, by)
  return math.atan2(by-ay, bx-ax)
end

local function _swipeDir(vx, vy)
  if math.abs(vx) > math.abs(vy) then
    return vx > 0 and "right" or "left"
  else
    return vy > 0 and "down" or "up"
  end
end

local function _touchList()
  local list = {}
  for _, t in pairs(_touches) do table.insert(list, t) end
  return list
end

-- ─── Public API ──────────────────────────────────────────────────────

function TouchManager.reset()
  _touches     = {}
  _touch_count = 0
  _tap_queue        = {}
  _double_tap_queue = {}
  _long_press_queue = {}
  _swipe_queue      = {}
  _pan = { active=false, x=0, y=0, dx=0, dy=0, vx=0, vy=0 }
  _pinch = { active=false, scale=1.0, cx=0, cy=0, angle=0, angle_delta=0 }
  _long_candidate = nil
  _pan_id = nil
end

function TouchManager.pressed(id, x, y)
  _touches[id] = { x=x, y=y, ox=x, oy=y, dx=0, dy=0, t=love.timer.getTime(), moved=false }
  _touch_count = _touch_count + 1

  -- Long press adayı: tek parmak
  if _touch_count == 1 then
    _long_candidate = { id=id, x=x, y=y, t=love.timer.getTime() }
    _pan_id = id
    _pan.active = false
    _pan.dx, _pan.dy = 0, 0
  else
    -- İkinci parmak geldi → long press iptal
    _long_candidate = nil
    _pan.active = false
    _pan_id = nil
  end

  -- İki parmak → pinch başlat
  if _touch_count == 2 then
    local list = _touchList()
    if #list == 2 then
      local a, b = list[1], list[2]
      _pinch.active   = false   -- henüz başlamadı (moved'da aktif olur)
      _pinch._init_d  = _dist(a.x, a.y, b.x, b.y)
      _pinch._init_a  = _angle(a.x, a.y, b.x, b.y)
      _pinch._prev_d  = _pinch._init_d
      _pinch._prev_a  = _pinch._init_a
      _pinch.scale    = 1.0
      _pinch.angle_delta = 0
    end
  end
end

function TouchManager.released(id, x, y)
  local touch = _touches[id]
  if not touch then return end

  local now  = love.timer.getTime()
  local dur  = now - touch.t
  local dist = _dist(touch.ox, touch.oy, x, y)

  -- Hız hesabı (son delta'dan)
  local vx = touch.dx / math.max(0.016, dur)
  local vy = touch.dy / math.max(0.016, dur)

  -- TAP tespiti
  if dur <= TAP_MAX_DUR and dist <= TAP_MAX_MOVE and _touch_count == 1 then
    -- Double tap kontrolü
    local dt_since = now - _last_tap.t
    local dd = _dist(_last_tap.x, _last_tap.y, x, y)
    if dt_since <= DOUBLE_TAP_DT and dd <= TAP_MAX_MOVE * 2 then
      table.insert(_double_tap_queue, { x=x, y=y })
      _last_tap.t = -999   -- reset (triple tap engeli)
    else
      table.insert(_tap_queue, { x=x, y=y })
      _last_tap = { t=now, x=x, y=y }
    end
  end

  -- SWIPE tespiti
  if dist >= SWIPE_MIN_D then
    local spd = math.sqrt(vx*vx + vy*vy)
    if spd >= SWIPE_MIN_V then
      table.insert(_swipe_queue, {
        x=x, y=y,
        ox=touch.ox, oy=touch.oy,
        dir=_swipeDir(x-touch.ox, y-touch.oy),
        vx=vx, vy=vy,
        dist=dist,
      })
    end
  end

  _touches[id]   = nil
  _touch_count   = math.max(0, _touch_count - 1)

  -- Long press iptal
  if _long_candidate and _long_candidate.id == id then
    _long_candidate = nil
  end

  -- Pan durdur
  if _pan_id == id then
    _pan_id = nil
    -- Fling: dokunma bırakıldığında momentum ekle
    if _pan.active then
      _pan.vx = vx
      _pan.vy = vy
    end
    _pan.active = false
    _pan.dx, _pan.dy = 0, 0
  end

  -- Pinch durdur
  if _touch_count < 2 then
    _pinch.active = false
  end
end

function TouchManager.moved(id, x, y, dx, dy)
  local touch = _touches[id]
  if not touch then return end

  touch.dx   = dx
  touch.dy   = dy
  touch.x    = x
  touch.y    = y

  local dist = _dist(touch.ox, touch.oy, x, y)
  if dist > PAN_MIN_D then touch.moved = true end

  -- Long press iptal (hareket)
  if touch.moved and _long_candidate and _long_candidate.id == id then
    _long_candidate = nil
  end

  -- Pan (tek parmak)
  if _touch_count == 1 and _pan_id == id and touch.moved then
    _pan.active = true
    _pan.x, _pan.y = x, y
    _pan.dx, _pan.dy = dx, dy
    _pan.vx, _pan.vy = 0, 0   -- hız bırakma ile hesaplanır
  end

  -- Pinch (iki parmak)
  if _touch_count == 2 then
    local list = _touchList()
    if #list == 2 then
      local a, b = list[1], list[2]
      local cur_d = _dist(a.x, a.y, b.x, b.y)
      local cur_a = _angle(a.x, a.y, b.x, b.y)

      local scale_delta = cur_d / math.max(1, _pinch._prev_d)
      local angle_delta = cur_a - _pinch._prev_a

      -- Açı sarma (-π/+π)
      while angle_delta >  math.pi do angle_delta = angle_delta - 2*math.pi end
      while angle_delta < -math.pi do angle_delta = angle_delta + 2*math.pi end

      _pinch.active      = true
      _pinch.scale       = scale_delta
      _pinch.angle_delta = angle_delta
      _pinch.cx          = (a.x + b.x) / 2
      _pinch.cy          = (a.y + b.y) / 2
      _pinch._prev_d     = cur_d
      _pinch._prev_a     = cur_a
    end
  end
end

function TouchManager.update(dt)
  local now = love.timer.getTime()

  -- Long press
  if _long_candidate then
    local elapsed = now - _long_candidate.t
    if elapsed >= LONG_PRESS_DT then
      local touch = _touches[_long_candidate.id]
      if touch and not touch.moved then
        table.insert(_long_press_queue, { x=_long_candidate.x, y=_long_candidate.y })
      end
      _long_candidate = nil
    end
  end

  -- Fling momentumu sönümle
  if not _pan.active and (_pan.vx ~= 0 or _pan.vy ~= 0) then
    local damp = 0.88
    _pan.vx = _pan.vx * damp
    _pan.vy = _pan.vy * damp
    if math.abs(_pan.vx) < 1 and math.abs(_pan.vy) < 1 then
      _pan.vx, _pan.vy = 0, 0
    end
  else
    _pan.vx, _pan.vy = 0, 0
  end

  -- Frame başı: pinch scale sıfırla (frame bazlı delta)
  if not _pinch.active then
    _pinch.scale       = 1.0
    _pinch.angle_delta = 0
  end
end

-- ─── Consume fonksiyonları ────────────────────────────────────────────

--- Kuyruktaki ilk tap'ı döndürür ve siler, yoksa nil
function TouchManager.consumeTap()
  return table.remove(_tap_queue, 1)
end

--- Kuyruktaki ilk double-tap'ı döndürür ve siler
function TouchManager.consumeDoubleTap()
  return table.remove(_double_tap_queue, 1)
end

--- Kuyruktaki ilk long-press'i döndürür ve siler
function TouchManager.consumeLongPress()
  return table.remove(_long_press_queue, 1)
end

--- Kuyruktaki ilk swipe'ı döndürür ve siler
-- Dönen tablo: { x, y, ox, oy, dir="up"|"down"|"left"|"right", vx, vy, dist }
function TouchManager.consumeSwipe()
  return table.remove(_swipe_queue, 1)
end

--- Aktif pan durumunu döndürür (frame bazlı, consume gerekmez)
-- { active, x, y, dx, dy, vx, vy }
function TouchManager.getPan()
  return _pan
end

--- Aktif fling momentumunu döndürür (pan bırakıldıktan sonra)
function TouchManager.getFling()
  if not _pan.active and (_pan.vx ~= 0 or _pan.vy ~= 0) then
    return { active=true, vx=_pan.vx, vy=_pan.vy }
  end
  return { active=false, vx=0, vy=0 }
end

--- Aktif pinch durumunu döndürür (frame bazlı, consume gerekmez)
-- { active, scale, cx, cy, angle_delta }
-- scale: 1.0=değişmedi, >1.0=yakınlaştı, <1.0=uzaklaştı
function TouchManager.getPinch()
  return _pinch
end

--- Aktif dokunma sayısı
function TouchManager.count()
  return _touch_count
end

--- Belirli bir ID'nin aktif olup olmadığı
function TouchManager.isActive(id)
  return _touches[id] ~= nil
end

return TouchManager
