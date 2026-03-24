--[[
  AudioManager — Merkezi Ses Yöneticisi

  Katmanlar:
    AMBIYANS  — döngüsel bölge sesi (fade cross-fade desteği)
    MÜZİK     — moral ağırlığına bağlı katman geçişleri
    SFX       — tek seferlik efektler (havuz sistemi)

  Kullanım:
    AudioManager.init()
    AudioManager.setRegion("gaza")          -- ambiyans başlat
    AudioManager.playSFX("typewriter")      -- sfx çal
    AudioManager.setMoralWeight(0.3)        -- 0=ağır, 1=umutlu
    AudioManager.update(dt)                 -- her frame
    AudioManager.setVolume("sfx", 0.8)
--]]

local Synth        = require("src.systems.synth")
local SaveSystem   = require("src.systems.save_system")

local AudioManager = {}

-- Ses seviyeleri
local _vol = {
  master  = 1.0,
  ambient = 0.7,
  sfx     = 0.9,
}

-- Aktif ambiyans
local _ambient = {
  current  = nil,   -- aktif Source
  region   = nil,   -- bölge id
  fading   = nil,   -- solma Source
  fade_out = 0,     -- solma süresi sayacı
  fade_in  = 0,     -- yükseliş sayacı
  FADE_DUR = 2.0,   -- geçiş süresi (sn)
}

-- SFX havuzu — aynı ses eş zamanlı birden fazla çalabilsin
local _sfx_pool = {}
local POOL_SIZE  = 6

-- Önbellek — bir kez sentezle, tekrar kullan
local _cache = {}

local function _getCached(name, factory)
  if not _cache[name] then
    -- Her SFX için küçük havuz oluştur
    _cache[name] = {}
    for _ = 1, POOL_SIZE do
      local src = factory()
      src:setVolume(_vol.sfx * _vol.master)
      table.insert(_cache[name], src)
    end
  end
  return _cache[name]
end

local function _getFreeSFX(name)
  local pool = _cache[name]
  if not pool then return nil end
  for _, src in ipairs(pool) do
    if not src:isPlaying() then return src end
  end
  -- Hepsi meşgul — birini durdur
  local src = pool[1]
  src:stop()
  return src
end

-- ─── Başlatma ──────────────────────────────────────────────────────

function AudioManager.init()
  -- Ayarlardan ses seviyelerini yükle
  local sfx_vol   = SaveSystem.getSetting("sfx",   0.9)
  local music_vol = SaveSystem.getSetting("music",  0.7)
  _vol.sfx     = sfx_vol
  _vol.ambient = music_vol
  _vol.master  = 1.0

  -- SFX'leri ön sentezle (boot sırasında çağrılır, tek seferlik)
  AudioManager._presynthAll()
end

function AudioManager._presynthAll()
  -- Tip → fabrika fonksiyonu
  local defs = {
    typewriter     = function() return Synth.typewriterClick()  end,
    page_flip      = function() return Synth.pageFlip()          end,
    map_hover      = function() return Synth.mapHover()          end,
    map_select     = function() return Synth.mapSelect()         end,
    positive       = function() return Synth.positiveChime()     end,
    tension        = function() return Synth.tensionPulse()      end,
    weighted_moment= function() return Synth.weightedMoment()    end,
    chapter_done   = function() return Synth.chapterComplete()   end,
  }
  for name, factory in pairs(defs) do
    _getCached(name, factory)
  end
end

-- ─── SFX ───────────────────────────────────────────────────────────

--- Ses efekti çal
-- @param name  string  ses adı
-- @param vol   number  opsiyonel çarpan (varsayılan 1.0)
function AudioManager.playSFX(name, vol)
  local src = _getFreeSFX(name)
  if not src then return end
  local v = (vol or 1.0) * _vol.sfx * _vol.master
  src:setVolume(math.max(0, math.min(1, v)))
  src:seek(0)
  src:play()
end

-- ─── Ambiyans ──────────────────────────────────────────────────────

--- Bölge ambiyansını değiştir (cross-fade)
function AudioManager.setRegion(region_id)
  if _ambient.region == region_id then return end

  local new_src = Synth.ambientDrone(region_id)
  new_src:setVolume(0)
  new_src:play()

  -- Eski kaynağı solmaya bırak
  if _ambient.current then
    _ambient.fading  = _ambient.current
    _ambient.fade_out= 0
  end

  _ambient.current = new_src
  _ambient.region  = region_id
  _ambient.fade_in = 0
end

--- Ambiyansı kapat (yumuşak)
function AudioManager.stopAmbient()
  if _ambient.current then
    _ambient.fading   = _ambient.current
    _ambient.fade_out = 0
    _ambient.current  = nil
    _ambient.region   = nil
  end
end

-- ─── Update ────────────────────────────────────────────────────────

function AudioManager.update(dt)
  local fd = _ambient.FADE_DUR

  -- Fade in — yeni ambiyans
  if _ambient.current then
    _ambient.fade_in = math.min(fd, _ambient.fade_in + dt)
    local v = (_ambient.fade_in / fd) * _vol.ambient * _vol.master
    _ambient.current:setVolume(math.max(0, math.min(1, v)))
  end

  -- Fade out — eski ambiyans
  if _ambient.fading then
    _ambient.fade_out = _ambient.fade_out + dt
    local v = (1 - _ambient.fade_out / fd) * _vol.ambient * _vol.master
    if v <= 0 then
      _ambient.fading:stop()
      _ambient.fading = nil
    else
      _ambient.fading:setVolume(math.max(0, v))
    end
  end
end

-- ─── Ses Seviyesi Kontrolü ─────────────────────────────────────────

function AudioManager.setVolume(channel, value)
  value = math.max(0, math.min(1, value))
  if channel == "master" then
    _vol.master = value
  elseif channel == "ambient" or channel == "music" then
    _vol.ambient = value
    SaveSystem.setSetting("music", value)
    if _ambient.current then
      _ambient.current:setVolume(value * _vol.master)
    end
  elseif channel == "sfx" then
    _vol.sfx = value
    SaveSystem.setSetting("sfx", value)
    -- Havuz güncellemesi
    for name, pool in pairs(_cache) do
      for _, src in ipairs(pool) do
        if not src:isPlaying() then
          src:setVolume(value * _vol.master)
        end
      end
    end
  end
end

function AudioManager.getVolume(channel)
  return _vol[channel] or _vol.master
end

--- Tüm sesleri durdur
function AudioManager.stopAll()
  AudioManager.stopAmbient()
  for _, pool in pairs(_cache) do
    for _, src in ipairs(pool) do src:stop() end
  end
end

--- Moral ağırlığı — ileride müzik katmanı ayarlamak için hook
-- weight: 0.0 (en ağır/karanlık) → 1.0 (umutlu)
function AudioManager.setMoralWeight(weight)
  -- Şimdilik sadece ambient hacmini etkiler;
  -- ileride farklı müzik katmanlarına bağlanacak
  local ambient_adj = 0.5 + weight * 0.5   -- 0.5→1.0 arası
  if _ambient.current then
    local v = ambient_adj * _vol.ambient * _vol.master
    -- Gradüel geçiş (update'de fade ile yapılıyor)
  end
end

return AudioManager
