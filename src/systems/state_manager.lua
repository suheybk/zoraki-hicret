--[[
  StateManager — Sonlu Durum Makinesi
  
  Kullanım:
    StateManager.register("world_map", WorldMapState)
    StateManager.switch("world_map")
    StateManager.switch("chapter", { chapter_id = "gaza" })  -- veri geçişi
  
  Her durum modülü şu fonksiyonları opsiyonel olarak tanımlayabilir:
    state:enter(data)       -- geçiş geldiğinde
    state:leave()           -- geçiş ayrılırken
    state:update(dt)
    state:draw()
    state:keypressed(k,s,r)
    state:keyreleased(k,s)
    state:mousepressed(x,y,btn)
    state:mousereleased(x,y,btn)
    state:touchpressed(id,x,y,p)
    state:touchreleased(id,x,y,p)
    state:touchmoved(id,x,y,dx,dy,p)
--]]

local StateManager = {}

local _registry  = {}   -- isim → fabrika fonksiyonu / tablo
local _current   = nil  -- aktif durum örneği
local _stack     = {}   -- geçmiş durumlar (geri dönüş için)
local _name      = nil  -- aktif durum adı

--- Durum sınıfını kaydet
-- @param name    string   benzersiz durum adı
-- @param module  table    durum modülü (new() fonksiyonu varsa fabrika, yoksa singleton)
function StateManager.register(name, module)
  assert(type(name) == "string", "Durum adı string olmalı")
  assert(type(module) == "table", "Durum modülü tablo olmalı")
  _registry[name] = module
end

--- Duruma geç (stack temizler)
-- @param name  string  hedef durum adı
-- @param data  table   opsiyonel geçiş verisi
function StateManager.switch(name, data)
  assert(_registry[name], "Bilinmeyen durum: " .. tostring(name))

  -- Mevcut durumu kapat
  if _current and _current.leave then
    _current:leave()
  end

  -- Stack'i temizle
  _stack = {}

  -- Yeni durum örneği oluştur
  local mod = _registry[name]
  local instance
  if mod.new then
    instance = mod.new()
  else
    instance = mod
  end

  _current = instance
  _name    = name

  if _current.enter then
    _current:enter(data or {})
  end
end

--- Durumu stack üzerine it (geri dönülebilir)
function StateManager.push(name, data)
  assert(_registry[name], "Bilinmeyen durum: " .. tostring(name))

  if _current and _current.pause then
    _current:pause()
  end
  table.insert(_stack, { instance = _current, name = _name })

  local mod = _registry[name]
  local instance = mod.new and mod.new() or mod
  _current = instance
  _name    = name

  if _current.enter then
    _current:enter(data or {})
  end
end

--- Stack'ten geri dön
function StateManager.pop(data)
  assert(#_stack > 0, "Stack boş, geri dönülecek durum yok")

  if _current and _current.leave then
    _current:leave()
  end

  local prev = table.remove(_stack)
  _current = prev.instance
  _name    = prev.name

  if _current and _current.resume then
    _current:resume(data or {})
  end
end

--- Aktif durum adını döndür
function StateManager.current()
  return _name
end

-- ─── Döngü yönlendirme ─────────────────────────────────────────────

function StateManager.update(dt)
  if _current and _current.update then
    _current:update(dt)
  end
end

function StateManager.draw()
  if _current and _current.draw then
    _current:draw()
  end
end

function StateManager.keypressed(k, s, r)
  if _current and _current.keypressed then _current:keypressed(k, s, r) end
end

function StateManager.keyreleased(k, s)
  if _current and _current.keyreleased then _current:keyreleased(k, s) end
end

function StateManager.mousepressed(x, y, btn)
  if _current and _current.mousepressed then _current:mousepressed(x, y, btn) end
end

function StateManager.mousereleased(x, y, btn)
  if _current and _current.mousereleased then _current:mousereleased(x, y, btn) end
end

function StateManager.touchpressed(id, x, y, p)
  if _current and _current.touchpressed then _current:touchpressed(id, x, y, p) end
end

function StateManager.touchreleased(id, x, y, p)
  if _current and _current.touchreleased then _current:touchreleased(id, x, y, p) end
end

function StateManager.touchmoved(id, x, y, dx, dy, p)
  if _current and _current.touchmoved then _current:touchmoved(id, x, y, dx, dy, p) end
end

--- Aktif durum örneğini döndür (main.lua hook için)
function StateManager._getCurrent()
  return _current
end

--- Mouse wheel yönlendirmesi
function StateManager.wheelmoved(mx, my, dy)
  if _current and _current.wheelmoved then
    _current:wheelmoved(mx, my, dy)
  end
end

--- Mouse moved yönlendirmesi
function StateManager.mousemoved(mx, my, dx, dy)
  if _current and _current.mousemoved then
    _current:mousemoved(mx, my, dx, dy)
  end
end

return StateManager
