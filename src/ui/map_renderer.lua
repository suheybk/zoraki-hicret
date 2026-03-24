--[[
  MapRenderer — Prosedürel Dünya Haritası
  
  Harici görsel gerektirmez. Kıta poligonları lon/lat koordinatlarıyla
  tanımlanmış; Mercator benzeri projeksiyon ile 1280×720 sanal canvas'a çizilir.
  
  Koordinat sistemi:
    Boylam: -180 → +180
    Enlem:  +75  → -60
    Canvas: x 40→1240  y 30→690
    
  Kullanım:
    local MapRenderer = require("src.ui.map_renderer")
    MapRenderer.init()         -- bir kez
    MapRenderer.draw(timer)    -- her frame
--]]

local MapRenderer = {}

-- ─── Projeksiyon ────────────────────────────────────────────────────

local MAP_X0, MAP_Y0 = 40,  30
local MAP_W,  MAP_H  = 1200, 660
local LON_MIN, LON_MAX = -180, 180
local LAT_MAX, LAT_MIN =   75, -60

local function lon2x(lon)
  return MAP_X0 + (lon - LON_MIN) / (LON_MAX - LON_MIN) * MAP_W
end

local function lat2y(lat)
  return MAP_Y0 + (LAT_MAX - lat) / (LAT_MAX - LAT_MIN) * MAP_H
end

--- lon/lat çiftleri dizisini love.graphics uyumlu düz koordinat dizisine çevir
local function poly(pairs_tbl)
  local pts = {}
  for i = 1, #pairs_tbl, 2 do
    table.insert(pts, lon2x(pairs_tbl[i]))
    table.insert(pts, lat2y(pairs_tbl[i+1]))
  end
  return pts
end

-- ─── Kıta Poligon Veritabanı ────────────────────────────────────────
-- Her giriş: { fill={r,g,b,a}, line={r,g,b,a}, pts={lon,lat,...} }

local CONTINENTS = {}

-- AFRİKA
CONTINENTS[#CONTINENTS+1] = { name="africa",
  pts=poly({
    -6,36,   10,38,  25,32,  35,31,  37,22,
    43,15,   51,12,  44,11,  42,2,   42,-2,
    40,-10,  36,-18, 34,-35, 27,-35, 20,-35,
    17,-29,  14,-22, 11,-17, 10,-1,  2,5,
    -5,5,    -17,5,  -17,15, -17,25, -13,36, -6,36
  })
}

-- AVRUPA (Basitleştirilmiş)
CONTINENTS[#CONTINENTS+1] = { name="europe",
  pts=poly({
    -9,44,  -9,36,  -6,36,  0,38,   3,44,
    5,44,   8,44,   10,44,  12,40,  15,38,
    16,41,  20,42,  25,42,  30,42,  30,47,
    34,47,  36,42,  38,42,  40,45,  40,48,
    38,55,  30,60,  28,70,  20,71,
    15,70,  10,63,  5,58,   -3,51,
    -5,48,  -9,44
  })
}

-- ASYA (Batı Asya dahil)
CONTINENTS[#CONTINENTS+1] = { name="asia",
  pts=poly({
    26,42,  40,42,  40,48,  50,42,  60,37,
    65,24,  57,22,  57,12,  51,12,  44,14,
    43,36,  38,42,  36,42,  34,47,
    50,52,  60,55,  70,55,  80,55,
    90,55,  100,55, 110,55, 120,55,
    130,50, 140,46, 141,40, 132,32,
    121,25, 110,20, 105,12, 100,5,
    103,1,  105,-5, 115,-8, 119,-8,
    120,-5, 115,0,  110,5,  105,12,
    100,20, 95,22,  90,22,  80,15,
    73,8,   72,20,  68,24,  62,22,
    58,22,  57,12,
    -- Geri kuzey boyunca
    50,42,  40,48,  30,60,  40,70,
    60,73,  80,73,  100,73, 120,73,
    140,73, 141,40,
    132,32, 130,36, 125,40,
    120,40, 115,38, 110,38,
    105,42, 100,50, 90,55,
    80,55,  70,55,  60,55,
    50,52,  40,48
  })
}

-- KUZEY AMERİKA
CONTINENTS[#CONTINENTS+1] = { name="north_america",
  pts=poly({
    -167,68, -140,70, -120,74, -100,74, -80,74,
    -63,68,  -52,60,  -55,48,  -60,44,
    -65,40,  -75,36,  -80,26,  -87,20,
    -90,16,  -83,10,  -77,8,
    -78,9,   -82,8,   -84,10,  -88,16,
    -92,16,  -96,20,  -100,22, -105,23,
    -110,24, -117,32, -124,38, -124,48,
    -130,55, -140,60, -148,60, -160,60,
    -167,60, -167,68
  })
}

-- GÜNEY AMERİKA
CONTINENTS[#CONTINENTS+1] = { name="south_america",
  pts=poly({
    -73,12, -63,12, -53,6,  -50,2,
    -50,-4, -35,-4, -34,-7,
    -36,-10,-39,-15,-40,-22,
    -44,-23,-48,-28,-52,-33,
    -58,-38,-62,-42,-65,-45,
    -68,-52,-68,-55,-65,-55,
    -60,-52,-55,-48,-50,-40,
    -48,-28,-43,-23,-42,-15,
    -40,-5, -50,2,
    -60,5,  -68,6,  -73,10, -73,12
  })
}

-- AVUSTRALYA
CONTINENTS[#CONTINENTS+1] = { name="australia",
  pts=poly({
    114,-22, 114,-26, 118,-36,
    122,-36, 130,-34, 137,-35,
    140,-38, 146,-40, 150,-38,
    153,-30, 153,-26, 150,-22,
    144,-18, 136,-12, 130,-12,
    124,-16, 118,-20, 114,-22
  })
}

-- ANTARKTİKA (sadece kuzey kıyı çizgisi)
CONTINENTS[#CONTINENTS+1] = { name="antarctica",
  pts=poly({
    -180,-65, -160,-70, -140,-68, -120,-70,
    -100,-68, -80,-70,  -60,-68,  -40,-70,
    -20,-68,  0,-70,    20,-68,   40,-70,
    60,-68,   80,-70,   100,-68,  120,-70,
    140,-68,  160,-70,  180,-65
  })
}

-- JAPONYA (küçük ada)
CONTINENTS[#CONTINENTS+1] = { name="japan",
  pts=poly({
    130,32, 132,34, 134,36, 135,38,
    137,40, 140,42, 141,40, 140,38,
    138,36, 136,34, 133,33, 130,32
  })
}

-- GBRİTANYA
CONTINENTS[#CONTINENTS+1] = { name="uk",
  pts=poly({
    -5,50, -3,52, -4,54, -3,56,
    -2,58, 0,58,  1,54,  0,52, -2,50, -5,50
  })
}

-- ─── Meridyen / Paralel Izgara ──────────────────────────────────────

local function drawGrid()
  -- Meridyenler (30° aralık)
  love.graphics.setColor(0.18, 0.16, 0.13, 0.5)
  love.graphics.setLineWidth(0.3)
  for lon = -180, 180, 30 do
    local x = lon2x(lon)
    love.graphics.line(x, MAP_Y0, x, MAP_Y0 + MAP_H)
  end
  -- Paraleller (15° aralık)
  for lat = 75, -60, -15 do
    local y = lat2y(lat)
    love.graphics.line(MAP_X0, y, MAP_X0 + MAP_W, y)
  end

  -- Ekvatör — daha belirgin
  love.graphics.setColor(0.30, 0.26, 0.20, 0.6)
  love.graphics.setLineWidth(0.5)
  love.graphics.line(MAP_X0, lat2y(0), MAP_X0+MAP_W, lat2y(0))

  -- Dönenceler
  love.graphics.setColor(0.35, 0.28, 0.18, 0.35)
  love.graphics.setLineWidth(0.3)
  love.graphics.line(MAP_X0, lat2y(23.5), MAP_X0+MAP_W, lat2y(23.5))
  love.graphics.line(MAP_X0, lat2y(-23.5), MAP_X0+MAP_W, lat2y(-23.5))
end

local function drawCoordLabels(font)
  if not font then return end
  love.graphics.setFont(font)
  -- Boylam etiketleri (alt)
  for lon = -150, 180, 30 do
    local x = lon2x(lon)
    local label = tostring(math.abs(lon)) .. (lon >= 0 and "E" or "W")
    love.graphics.setColor(0.28, 0.25, 0.20, 0.6)
    love.graphics.print(label, x - font:getWidth(label)/2, MAP_Y0 + MAP_H + 4)
  end
  -- Enlem etiketleri (sol)
  for lat = 60, -45, -15 do
    local y = lat2y(lat)
    local label = tostring(math.abs(lat)) .. (lat >= 0 and "N" or "S")
    love.graphics.setColor(0.28, 0.25, 0.20, 0.6)
    love.graphics.print(label, MAP_X0 - font:getWidth(label) - 4, y - 5)
  end
end

-- ─── Dekoratif Öğeler ───────────────────────────────────────────────

local function drawMapBorder()
  -- Dış çerçeve
  love.graphics.setColor(0.35, 0.30, 0.22, 0.7)
  love.graphics.setLineWidth(0.5)
  love.graphics.rectangle("line", MAP_X0 - 2, MAP_Y0 - 2, MAP_W + 4, MAP_H + 4)
  -- İç köşe aksan
  local cs = 8
  love.graphics.setColor(0.55, 0.45, 0.28, 0.5)
  -- Sol üst
  love.graphics.line(MAP_X0-2, MAP_Y0-2+cs, MAP_X0-2, MAP_Y0-2, MAP_X0-2+cs, MAP_Y0-2)
  -- Sağ üst
  love.graphics.line(MAP_X0+MAP_W+2-cs, MAP_Y0-2, MAP_X0+MAP_W+2, MAP_Y0-2, MAP_X0+MAP_W+2, MAP_Y0-2+cs)
  -- Sol alt
  love.graphics.line(MAP_X0-2, MAP_Y0+MAP_H+2-cs, MAP_X0-2, MAP_Y0+MAP_H+2, MAP_X0-2+cs, MAP_Y0+MAP_H+2)
  -- Sağ alt
  love.graphics.line(MAP_X0+MAP_W+2, MAP_Y0+MAP_H+2-cs, MAP_X0+MAP_W+2, MAP_Y0+MAP_H+2, MAP_X0+MAP_W+2-cs, MAP_Y0+MAP_H+2)
end

local function drawStampOverlay(timer)
  -- Sol üst: "SINIFLI" damgası hissi
  love.graphics.setColor(0.55, 0.35, 0.20, 0.08)
  -- Dörtgen izleme çizgileri (bearing lines — klasik harita dekorasyon)
  love.graphics.setLineWidth(0.3)
  local cx, cy = lon2x(35), lat2y(30)  -- Orta Doğu merkezi
  for i = 0, 7 do
    local angle = i * math.pi / 4 + timer * 0.03
    local r = 200
    love.graphics.line(cx, cy, cx + math.cos(angle)*r, cy + math.sin(angle)*r)
  end
end

-- ─── Okyanus Adı Etiketleri ─────────────────────────────────────────

local OCEAN_LABELS = {
  { text="PASIFIK OKYANUSU", lon=-150, lat=5  },
  { text="ATLANTİK OKYANUSU",lon=-35,  lat=5  },
  { text="HİNT OKYANUSU",    lon=75,   lat=-20 },
  { text="ARKTİK",           lon=0,    lat=70  },
}

local function drawOceanLabels(font)
  if not font then return end
  love.graphics.setFont(font)
  for _, lbl in ipairs(OCEAN_LABELS) do
    local x = lon2x(lbl.lon)
    local y = lat2y(lbl.lat)
    local tw = font:getWidth(lbl.text)
    love.graphics.setColor(0.35, 0.33, 0.28, 0.4)
    love.graphics.print(lbl.text, x - tw/2, y - 5)
  end
end

-- ─── API ─────────────────────────────────────────────────────────────

local _font_coord = nil
local _font_ocean = nil

function MapRenderer.init()
  _font_coord = love.graphics.newFont(9)
  _font_ocean = love.graphics.newFont(10)
end

--- Ana çizim fonksiyonu
function MapRenderer.draw(timer)
  timer = timer or 0

  -- Okyanus arka planı
  love.graphics.setColor(0.06, 0.08, 0.10, 1)
  love.graphics.rectangle("fill", MAP_X0, MAP_Y0, MAP_W, MAP_H)

  -- Izgara
  drawGrid()

  -- Kıtalar — önce dolgu, sonra çizgi
  for _, cont in ipairs(CONTINENTS) do
    if #cont.pts >= 6 then
      -- Dolgu
      love.graphics.setColor(0.12, 0.11, 0.09, 1)
      local ok = pcall(love.graphics.polygon, "fill", cont.pts)
      if not ok then
        -- love.graphics.polygon convex only fallback: çizgi
      end
      -- Çizgi
      love.graphics.setColor(0.30, 0.27, 0.21, 0.85)
      love.graphics.setLineWidth(0.6)
      love.graphics.polygon("line", cont.pts)
    end
  end

  -- Dekoratif öğeler
  drawStampOverlay(timer)
  drawCoordLabels(_font_coord)
  drawOceanLabels(_font_ocean)
  drawMapBorder()

  love.graphics.setLineWidth(1)
  love.graphics.setColor(1, 1, 1, 1)
end

--- Lon/lat → ekran koordinatı (region dot konumlandırma için)
function MapRenderer.project(lon, lat)
  return lon2x(lon), lat2y(lat)
end

--- Harita sınırları (debug/layout için)
function MapRenderer.bounds()
  return MAP_X0, MAP_Y0, MAP_W, MAP_H
end

return MapRenderer
