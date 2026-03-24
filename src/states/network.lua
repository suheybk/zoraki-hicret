--[[
  NetworkState — Zulüm Ağı Tam Ekran Görüntüleyicisi
  
  StateManager.push("network", { region_id="gaza", level=2 })
  ile açılır; ESC / Geri ile kapanır.
  
  Kilit seviyesi (level) oyun ilerledikçe artabilir.
  Outcome ekranından, Archive'dan veya Act içindeki özel node'lardan erişilir.
--]]

local StateManager = require("src.systems.state_manager")
local NetworkUI    = require("src.ui.network_ui")
local NetworkData  = require("src.systems.network_data")
local AudioManager = require("src.systems.audio_manager")
local SaveSystem   = require("src.systems.save_system")
local Config       = require("src.utils.config")
local TouchManager = require("src.systems.touch_manager")
local MapCamera    = require("src.systems.map_camera")

local NetworkState = {}
NetworkState.__index = NetworkState

-- ─── Sabitler ────────────────────────────────────────────────────────

local PANEL_PAD   = 16     -- harita kenar boşluğu
local LEGEND_W    = 170    -- sağ lejant genişliği
local HEADER_H    = 48     -- üst çubuk yüksekliği
local FOOTER_H    = 38     -- alt çubuk yüksekliği

function NetworkState.new()
  return setmetatable({}, NetworkState)
end

function NetworkState:enter(data)
  data = data or {}
  self.region_id    = data.region_id or "gaza"
  self.unlock_level = data.level     or 0

  self.fade  = 1
  self.timer = 0

  -- Ağ UI bileşeni
  self.net = NetworkUI.new(self.region_id, self.unlock_level)

  -- Fontlar
  self.f_title  = love.graphics.newFont(18)
  self.f_label  = love.graphics.newFont(12)
  self.f_small  = love.graphics.newFont(10)
  self.f_mono   = love.graphics.newFont(10)

  -- Kilit aç butonu (test: seviye yükselt)
  self._level_btns = {}
  local max = NetworkData.maxLevel(self.region_id)
  for lvl = 0, max do
    table.insert(self._level_btns, {
      level = lvl,
      label = "Sev." .. lvl,
    })
  end
  self._hover_lvl = nil

  -- Kamera
  local W2, H2 = Config.vw(), Config.vh()
  local NET_W2 = W2 - PANEL_PAD*2 - LEGEND_W - 8
  local NET_H2 = H2 - HEADER_H - FOOTER_H - PANEL_PAD*2
  self.cam = MapCamera.new(NET_W2, NET_H2, NET_W2, NET_H2)
  self.cam:reset()

  -- Ses: ağırlıklı an sesi
  AudioManager.playSFX("weighted_moment", 0.6)
end

function NetworkState:leave()
end

-- ─── Layout Hesabı ───────────────────────────────────────────────────

function NetworkState:_layout()
  local W, H = Config.vw(), Config.vh()
  local net_x = PANEL_PAD
  local net_y = HEADER_H + PANEL_PAD
  local net_w = W - PANEL_PAD*2 - LEGEND_W - 8
  local net_h = H - HEADER_H - FOOTER_H - PANEL_PAD*2
  return W, H, net_x, net_y, net_w, net_h
end

-- ─── Update ──────────────────────────────────────────────────────────

function NetworkState:update(dt)
  self.timer = self.timer + dt
  if self.fade > 0 then self.fade = math.max(0, self.fade - dt*2.5) end

  self.net:update(dt)
  self.cam:update(dt, TouchManager)

  -- Hover tespiti
  local mx, my = Config.toLogical(love.mouse.getPosition())
  local W, H, nx, ny, nw, nh = self:_layout()
  self.net:updateHover(mx, my)

  -- Seviye buton hover
  self._hover_lvl = nil
  for i, btn in ipairs(self._lvl_btn_rects or {}) do
    if mx >= btn.x and mx <= btn.x+btn.w and
       my >= btn.y and my <= btn.y+btn.h then
      self._hover_lvl = i
    end
  end
end

-- ─── Draw ────────────────────────────────────────────────────────────

function NetworkState:draw()
  local W, H, nx, ny, nw, nh = self:_layout()

  -- Genel arka plan
  love.graphics.setColor(0.04, 0.03, 0.03, 1)
  love.graphics.rectangle("fill", 0, 0, W, H)

  -- ① Üst çubuk
  self:_drawHeader(W)

  -- ② Ağ UI
  self.net:draw(nx, ny, nw, nh)

  -- ③ Sağ lejant
  self:_drawLegend(nx + nw + 8, ny, LEGEND_W, nh)

  -- ④ Alt çubuk
  self:_drawFooter(W, H)

  -- ⑤ Fade
  if self.fade > 0 then
    love.graphics.setColor(0, 0, 0, self.fade)
    love.graphics.rectangle("fill", 0, 0, W, H)
  end
  love.graphics.setColor(1,1,1,1)
  love.graphics.setLineWidth(1)
end

function NetworkState:_drawHeader(W)
  love.graphics.setColor(0.06, 0.05, 0.04, 0.95)
  love.graphics.rectangle("fill", 0, 0, W, HEADER_H)
  love.graphics.setColor(0.28, 0.24, 0.18, 0.6)
  love.graphics.setLineWidth(0.5)
  love.graphics.line(0, HEADER_H, W, HEADER_H)

  -- "Zulüm Ağı" etiketi
  love.graphics.setFont(self.f_mono)
  love.graphics.setColor(0.45, 0.40, 0.30, 0.75)
  love.graphics.print("// ZULÜM AĞI  ▸  İFŞA SİSTEMİ", 18, 10)

  -- Bölge adı
  love.graphics.setFont(self.f_title)
  love.graphics.setColor(0.84, 0.78, 0.62, 1)
  local region_names = {
    gaza="Gazze / Filistin", uyghur="Doğu Türkistan",
    rohingya="Arakan", syria="Suriye", yemen="Yemen", kashmir="Keşmir",
  }
  local rname = region_names[self.region_id] or self.region_id
  love.graphics.print(rname, 18, 24)

  -- Seviye göstergesi (sağ)
  love.graphics.setFont(self.f_small)
  love.graphics.setColor(0.40, 0.36, 0.28, 0.8)
  local lv_str = "Açık seviye: " .. self.unlock_level
  love.graphics.print(lv_str, W - self.f_small:getWidth(lv_str) - 18, 18)
end

function NetworkState:_drawLegend(lx, ly, lw, lh)
  -- Arka plan
  love.graphics.setColor(0.06, 0.05, 0.04, 0.92)
  love.graphics.rectangle("fill", lx, ly, lw, lh, 6)
  love.graphics.setColor(0.22, 0.19, 0.15, 0.5)
  love.graphics.setLineWidth(0.5)
  love.graphics.rectangle("line", lx, ly, lw, lh, 6)

  love.graphics.setFont(self.f_mono)
  love.graphics.setColor(0.38, 0.35, 0.27, 0.8)
  love.graphics.print("// AKTÖR TİPİ", lx+10, ly+10)

  local type_entries = {
    { type="victim",  label="Mağdur Halk"     },
    { type="state",   label="Devlet"          },
    { type="corp",    label="Şirket"          },
    { type="finance", label="Finans"          },
    { type="media",   label="Medya"           },
    { type="law",     label="Hukuki Kurum"    },
    { type="tech",    label="Teknoloji"       },
    { type="ngo",     label="Örgüt"           },
  }

  local ey = ly + 28
  love.graphics.setFont(self.f_small)
  for _, entry in ipairs(type_entries) do
    local col = NetworkData.TYPE_COLORS[entry.type] or {0.5,0.5,0.5}
    love.graphics.setColor(col[1], col[2], col[3], 0.9)
    love.graphics.circle("fill", lx+14, ey+5, 5)
    love.graphics.setColor(0.70, 0.66, 0.54, 0.85)
    love.graphics.print(entry.label, lx+26, ey - 1)
    ey = ey + 17
  end

  -- Kenar tipi lejantı
  ey = ey + 8
  love.graphics.setFont(self.f_mono)
  love.graphics.setColor(0.38, 0.35, 0.27, 0.8)
  love.graphics.print("// BAĞLANTI", lx+10, ey)
  ey = ey + 16

  local edge_entries = {
    { type="arms",    label="Silah Tedariki"    },
    { type="finance", label="Finans"            },
    { type="veto",    label="Hukuki Veto"       },
    { type="silence", label="Medya Suskunluğu"  },
    { type="tech",    label="Teknoloji"         },
    { type="sanction",label="Yaptırım"          },
    { type="lobby",   label="Lobi"              },
  }

  love.graphics.setFont(self.f_small)
  for _, entry in ipairs(edge_entries) do
    if ey + 14 < ly + lh - 10 then
      local col = NetworkData.EDGE_COLORS[entry.type] or {0.5,0.5,0.5}
      love.graphics.setColor(col[1], col[2], col[3], 0.85)
      love.graphics.setLineWidth(1.5)
      love.graphics.line(lx+8, ey+6, lx+22, ey+6)
      love.graphics.setColor(0.65, 0.62, 0.50, 0.85)
      love.graphics.print(entry.label, lx+28, ey)
      ey = ey + 15
    end
  end

  -- Seviye kilit açma butonları (debug / sahne testi)
  ey = ly + lh - 16 * (#self._level_btns) - 14
  love.graphics.setFont(self.f_mono)
  love.graphics.setColor(0.30, 0.28, 0.22, 0.6)
  love.graphics.print("// KİLİT SEVİYESİ", lx+8, ey-14)

  self._lvl_btn_rects = {}
  for i, btn in ipairs(self._level_btns) do
    local bx = lx + 8
    local by = ey + (i-1)*16
    local bw = lw - 16
    local bh = 14
    table.insert(self._lvl_btn_rects, {x=bx, y=by, w=bw, h=bh})

    local active = btn.level == self.unlock_level
    local hot    = self._hover_lvl == i
    local bg_a   = active and 0.22 or (hot and 0.12 or 0.04)
    love.graphics.setColor(0.72, 0.60, 0.38, bg_a)
    love.graphics.rectangle("fill", bx, by, bw, bh, 3)
    love.graphics.setColor(0.72, 0.60, 0.38, active and 0.7 or 0.25)
    love.graphics.setLineWidth(0.5)
    love.graphics.rectangle("line", bx, by, bw, bh, 3)

    love.graphics.setFont(self.f_small)
    love.graphics.setColor(active and 0.88 or 0.45,
                           active and 0.82 or 0.42,
                           active and 0.65 or 0.32, 1)
    local lbl = btn.label
    local lbw = self.f_small:getWidth(lbl)
    love.graphics.print(lbl, bx + bw/2 - lbw/2, by + 1)
  end
  love.graphics.setLineWidth(1)
end

function NetworkState:_drawFooter(W, H)
  local fy = H - FOOTER_H
  love.graphics.setColor(0.06, 0.05, 0.04, 0.92)
  love.graphics.rectangle("fill", 0, fy, W, FOOTER_H)
  love.graphics.setColor(0.22, 0.19, 0.15, 0.5)
  love.graphics.setLineWidth(0.5)
  love.graphics.line(0, fy, W, fy)

  love.graphics.setFont(self.f_small)
  love.graphics.setColor(0.38, 0.35, 0.28, 0.8)
  love.graphics.print("[ ESC ] Geri    [ Tıkla ] Düğüm detayı    [ Üzerine gel ] Bağlantı detayı", 18, fy + 12)

  -- Kaynak notu
  local src = "Kaynaklar: SIPRI · BM Kayıtları · Amnesty Int. · Human Rights Watch"
  love.graphics.setColor(0.28, 0.26, 0.21, 0.6)
  love.graphics.print(src, W - self.f_small:getWidth(src) - 18, fy + 12)
end

-- ─── Girdi ───────────────────────────────────────────────────────────

function NetworkState:mousepressed(x, y, btn)
  if btn ~= 1 then return end
  self:_handlePress(x, y)
end

function NetworkState:touchpressed(id, x, y, p)
  self:_handlePress(x, y)
end

function NetworkState:_handlePress(x, y)
  -- Seviye butonları
  for i, rect in ipairs(self._lvl_btn_rects or {}) do
    if x >= rect.x and x <= rect.x+rect.w and
       y >= rect.y and y <= rect.y+rect.h then
      local btn = self._level_btns[i]
      if btn then
        self.unlock_level = btn.level
        self.net:setUnlockLevel(btn.level)
        AudioManager.playSFX("weighted_moment", 0.5)
      end
      return
    end
  end

  -- Ağ UI'ye ilet
  self.net:mousepressed(x, y)
end

function NetworkState:touchmoved(id, x, y, dx, dy, p)
  self.net:updateHover(x, y)
end

function NetworkState:keypressed(key)
  if key == "escape" then
    StateManager.pop()
  end
end

function NetworkState:wheelmoved(mx, my, dy)
  if self.cam then
    self.cam:wheelzoom(mx, my, dy)
  end
end

function NetworkState:touchpressed(id, x, y, p) end
function NetworkState:touchreleased(id, x, y, p) end
function NetworkState:touchmoved(id, x, y, dx, dy, p) end

return NetworkState
