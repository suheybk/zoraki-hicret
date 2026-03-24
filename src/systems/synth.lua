--[[
  Synth — Prosedürel Ses Sentezleyici
  Harici ses dosyası gerektirmez.
  love.sound.newSoundData() ile PCM tamponu üretir.

  API:
    Synth.typewriterClick()      → Source  (tek tuş tık)
    Synth.pageFlip()             → Source  (diyalog geçişi)
    Synth.ambientDrone(region)   → Source  (döngüsel ambiyans)
    Synth.tensionPulse()         → Source  (kırılma perdesi)
    Synth.positiveChime()        → Source  (yardım/dayanışma anı)
    Synth.mapHover()             → Source  (harita hover)
    Synth.mapSelect()            → Source  (bölge seçimi)
]]

local Synth = {}

local SAMPLE_RATE = 22050   -- 22kHz yeterli, bellek dostu
local CHANNELS    = 1       -- mono

-- ─── Temel dalga fonksiyonları ──────────────────────────────────────

local function sine(t, freq)    return math.sin(2 * math.pi * freq * t) end
local function square(t, freq)
  return sine(t, freq) >= 0 and 1.0 or -1.0
end
local function sawtooth(t, freq)
  return 2 * ((t * freq) % 1) - 1
end
local function noise()          return math.random() * 2 - 1 end

-- Zarf: Attack-Decay-Sustain-Release
local function adsr(t, dur, a, d, s_level, r)
  if t < a then                          return t / a
  elseif t < a + d then                  return 1 - (t - a) / d * (1 - s_level)
  elseif t < dur - r then                return s_level
  elseif t <= dur then                   return s_level * (1 - (t - (dur - r)) / r)
  else                                   return 0 end
end

-- ─── Kaynak fabrikası ───────────────────────────────────────────────

local function makeSoundData(duration_sec, gen_fn)
  local n     = math.floor(SAMPLE_RATE * duration_sec)
  local sd    = love.sound.newSoundData(n, SAMPLE_RATE, 16, CHANNELS)
  for i = 0, n - 1 do
    local t   = i / SAMPLE_RATE
    local val = gen_fn(t, duration_sec)
    -- Klip sınırı
    val = math.max(-1, math.min(1, val))
    sd:setSample(i, val)
  end
  return sd
end

local function toSource(sd, loop)
  local src = love.audio.newSource(sd)
  if loop then src:setLooping(true) end
  return src
end

-- ─── Ses Tarifleri ──────────────────────────────────────────────────

--- Typewriter tık — kısa gürültü patlaması + hafif perde
function Synth.typewriterClick()
  local sd = makeSoundData(0.06, function(t, dur)
    local env   = adsr(t, dur, 0.001, 0.015, 0.0, 0.044)
    local click = noise() * 0.6
    local tone  = sine(t, 2800) * 0.3     -- metalik çınlama
    return (click + tone) * env
  end)
  return toSource(sd)
end

--- Sayfa çevirme — yumuşak "fış" sesi
function Synth.pageFlip()
  local sd = makeSoundData(0.18, function(t, dur)
    local env  = adsr(t, dur, 0.004, 0.06, 0.0, 0.116)
    local swsh = noise() * 0.5
    -- Aşağı kayan süpürme filtresi simülasyonu (LPF yerine frekans modülasyon)
    local sweep = sine(t, 800 * (1 - t/dur)) * 0.25
    return (swsh + sweep) * env
  end)
  return toSource(sd)
end

--- Harita hover — hafif yükselen tını
function Synth.mapHover()
  local sd = makeSoundData(0.12, function(t, dur)
    local env  = adsr(t, dur, 0.01, 0.05, 0.0, 0.06)
    local tone = sine(t, 440 + t/dur * 220) * 0.4
    return tone * env
  end)
  return toSource(sd)
end

--- Harita seçim — çift tın, hafif dramatik
function Synth.mapSelect()
  local sd = makeSoundData(0.30, function(t, dur)
    local env  = adsr(t, dur, 0.005, 0.08, 0.15, 0.215)
    local f1   = sine(t, 320) * 0.4
    local f2   = sine(t, 480) * 0.3
    local f3   = sine(t, 640) * 0.15
    return (f1 + f2 + f3) * env
  end)
  return toSource(sd)
end

--- Dayanışma/yardım anı — yumuşak majör üçlü
function Synth.positiveChime()
  local sd = makeSoundData(0.8, function(t, dur)
    local env  = adsr(t, dur, 0.01, 0.2, 0.3, 0.59)
    -- Majör üçlü: C4-E4-G4 (261.6-329.6-392 Hz)
    local f1   = sine(t, 261.6) * 0.4
    local f2   = sine(t, 329.6) * 0.35
    local f3   = sine(t, 392.0) * 0.25
    -- Hafif vibrato
    local vib  = 1 + 0.003 * math.sin(2*math.pi*5.5*t)
    return (f1*vib + f2*vib + f3) * env
  end)
  return toSource(sd)
end

--- Gerilim nabzı — kırılma perdesi için alçak, ağır vuruş
function Synth.tensionPulse()
  local sd = makeSoundData(0.5, function(t, dur)
    local env  = adsr(t, dur, 0.005, 0.12, 0.05, 0.375)
    -- Sub bas vuruş
    local bass  = sine(t, 60 * (1 - t*0.8)) * 0.55
    -- Gürültü katmanı
    local nz    = noise() * 0.15 * math.exp(-t * 12)
    -- Minör ikinci tını (gerilim)
    local dissonance = sine(t, 220) * 0.1 * math.exp(-t*4)
    return (bass + nz + dissonance) * env
  end)
  return toSource(sd)
end

--- Ambiyans — bölgeye göre farklılaşan döngüsel ses ortamı
-- region: "gaza" | "uyghur" | "rohingya" | "syria" | "yemen" | "kashmir" | "map"
function Synth.ambientDrone(region)
  -- Her bölgenin kendi frekans ve gürültü karakteri var
  local profiles = {
    map      = { f1=80,  f2=120, f3=160, noise_amt=0.03, vol=0.25, dur=4.0 },
    gaza     = { f1=55,  f2=82,  f3=110, noise_amt=0.05, vol=0.28, dur=5.0 },  -- ağır, bas
    uyghur   = { f1=65,  f2=97,  f3=130, noise_amt=0.02, vol=0.22, dur=6.0 },  -- soğuk, metal
    rohingya = { f1=70,  f2=105, f3=140, noise_amt=0.06, vol=0.20, dur=5.5 },  -- rüzgarlı, belirsiz
    syria    = { f1=58,  f2=87,  f3=116, noise_amt=0.04, vol=0.26, dur=4.5 },
    yemen    = { f1=50,  f2=75,  f3=100, noise_amt=0.07, vol=0.30, dur=5.0 },  -- en ağır
    kashmir  = { f1=72,  f2=108, f3=144, noise_amt=0.02, vol=0.18, dur=6.5 },  -- dağ, uzak
  }
  local p = profiles[region] or profiles["map"]

  local sd = makeSoundData(p.dur, function(t, dur)
    -- Nefes alan zarf (sine modülasyonlu)
    local breathe = 0.7 + 0.3 * math.sin(2*math.pi * t / dur)
    -- Temel drone katmanları
    local d1 = sine(t, p.f1) * 0.50
    local d2 = sine(t, p.f2) * 0.30
    local d3 = sine(t, p.f3) * 0.15
    -- Hafif titreme (bölge kimliği)
    local tremolo = 1 + 0.04 * math.sin(2*math.pi * 0.3 * t)
    -- Arka plan gürültüsü
    local nz = noise() * p.noise_amt
    -- Döngü başı/sonu fade (dikişsiz döngü için)
    local fade_in  = math.min(1, t / 0.3)
    local fade_out = math.min(1, (dur - t) / 0.3)
    local fade     = math.min(fade_in, fade_out)
    return ((d1 + d2 + d3) * tremolo + nz) * breathe * fade * p.vol
  end)

  return toSource(sd, true)  -- looping=true
end

--- Moral ağırlığı geçiş sesi — istatistik/gerçek gösterildiğinde
function Synth.weightedMoment()
  local sd = makeSoundData(1.2, function(t, dur)
    local env  = adsr(t, dur, 0.02, 0.3, 0.1, 0.88)
    -- Minör akor: A2-C3-E3
    local f1   = sine(t, 110.0) * 0.45
    local f2   = sine(t, 130.8) * 0.30
    local f3   = sine(t, 164.8) * 0.20
    -- Reverb simülasyonu (eko katmanları)
    local echo1 = sine(t - 0.06 > 0 and t-0.06 or 0, 110.0) * 0.15
    local echo2 = sine(t - 0.12 > 0 and t-0.12 or 0, 130.8) * 0.08
    return (f1+f2+f3+echo1+echo2) * env
  end)
  return toSource(sd)
end

--- Bölge tamamlandı — hüzünlü ama tamamlanmış hissi
function Synth.chapterComplete()
  local sd = makeSoundData(1.8, function(t, dur)
    local env  = adsr(t, dur, 0.03, 0.4, 0.25, 1.37)
    -- Asılı bırakılmış majör 7'li (umut/hüzün arası)
    local f1   = sine(t, 261.6) * 0.40   -- C4
    local f2   = sine(t, 329.6) * 0.30   -- E4
    local f3   = sine(t, 392.0) * 0.20   -- G4
    local f4   = sine(t, 493.9) * 0.15   -- B4 (major 7)
    -- Yavaş vibrato
    local vib  = 1 + 0.006 * math.sin(2*math.pi * 4.5 * t)
    return (f1+f2*vib+f3+f4*vib) * env
  end)
  return toSource(sd)
end

return Synth
