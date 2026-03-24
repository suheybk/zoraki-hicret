--[[
  NetworkUI — Zulüm Ağı Görsel Renderer
  
  Force-directed layout + manuel sabit pozisyon karışımı.
  Düğümler tıklanabilir; kenar üzerinde detay tooltip görünür.
  Animasyonlu kenar akışı (dashes), parlayan düğümler, reveal efekti.
  
  Kullanım:
    local NetworkUI = require("src.ui.network_ui")
    local net = NetworkUI.new(region_id, unlock_level)
    net:update(dt)
    net:draw(x, y, w, h)
    net:mousepressed(lx, ly)
    net:mousereleased(lx, ly)
    net:touchpressed(id, lx, ly)
    net:touchreleased(id, lx, ly)
--]]

local NetworkData = require("src.systems.network_data")

local NetworkUI = {}
NetworkUI.__index = NetworkUI

-- ─── Sabitler ────────────────────────────────────────────────────────
local NODE_R        = 18     -- düğüm yarıçapı
local NODE_R_VICTIM = 22     -- mağdur düğümü daha büyük
local EDGE_SPEED    = 40     -- kenar animasyon piksel/sn
local REVEAL_DUR    = 0.8    -- yeni düğüm açılma süresi
local TOOLTIP_W     = 200    -- kenar tooltip genişliği

-- ─── Konstruktör ─────────────────────────────────────────────────────

function NetworkUI.new(region_id, unlock_level)
  local self = setmetatable({}, NetworkUI)

  self.region_id    = region_id
  self.unlock_level = unlock_level or 0
  self.timer        = 0

  -- Veriyi yükle
  local raw  = NetworkData.getUnlocked(region_id, unlock_level)
  self.title = raw and raw.title or "Ağ"
  self.nodes = {}
  self.edges = {}

  -- Düğüm haritası (id → node)
  self.node_map = {}

  -- Düğümleri kur
  for _, nd in ipairs(raw and raw.nodes or {}) do
    local node = {
      id       = nd.id,
      label    = nd.label,
      type     = nd.type,
      -- Normalize pozisyon (0-1) → gerçek piksel, draw'da hesaplanır
      nx       = nd.x,
      ny       = nd.y,
      x        = 0, y = 0,       -- gerçek piksel (hesaplanacak)
      reveal   = 0,              -- 0→1 açılma animasyonu
      selected = false,
      hover    = false,
    }
    table.insert(self.nodes, node)
    self.node_map[nd.id] = node
  end

  -- Kenarları kur
  for _, ed in ipairs(raw and raw.edges or {}) do
    local from = self.node_map[ed.from]
    local to   = self.node_map[ed.to]
    if from and to then
      table.insert(self.edges, {
        from    = from,
        to      = to,
        type    = ed.type,
        label   = ed.label,
        offset  = math.random() * 100,  -- animasyon fazı
        hover   = false,
      })
    end
  end

  -- Seçili detay
  self.selected_node = nil
  self.hover_edge    = nil

  -- Fontlar
  self.f_node   = love.graphics.newFont(10)
  self.f_detail = love.graphics.newFont(13)
  self.f_label  = love.graphics.newFont(11)
  self.f_title  = love.graphics.newFont(16)
  self.f_type   = love.graphics.newFont(9)

  -- Ekran boyutları (draw çağrısında güncellenir)
  self._cx, self._cy = 0, 0
  self._w,  self._h  = 0, 0

  -- Reveal animasyonu (yeni düğümler birer birer açılır)
  self._reveal_queue = {}
  for i, nd in ipairs(self.nodes) do
    nd.reveal = 0
    table.insert(self._reveal_queue, { node=nd, delay=(i-1)*0.12 })
  end
  self._reveal_timer = 0

  return self
end

-- ─── Seviye güncelle (yeni düğüm/kenar kilit aç) ─────────────────────

function NetworkUI:setUnlockLevel(level)
  if level == self.unlock_level then return end
  self.unlock_level = level

  local raw = NetworkData.getUnlocked(self.region_id, level)
  if not raw then return end

  -- Yeni düğümler ekle
  for _, nd in ipairs(raw.nodes) do
    if not self.node_map[nd.id] then
      local node = {
        id=nd.id, label=nd.label, type=nd.type,
        nx=nd.x, ny=nd.y, x=0, y=0,
        reveal=0, selected=false, hover=false,
      }
      table.insert(self.nodes, node)
      self.node_map[nd.id] = node
      -- Reveal kuyruğuna ekle
      table.insert(self._reveal_queue, { node=node, delay=0 })
    end
  end

  -- Yeni kenarlar ekle
  local existing = {}
  for _, ed in ipairs(self.edges) do
    existing[ed.from.id .. "_" .. ed.to.id] = true
  end
  for _, ed in ipairs(raw.edges) do
    local key = ed.from .. "_" .. ed.to
    if not existing[key] then
      local from = self.node_map[ed.from]
      local to   = self.node_map[ed.to]
      if from and to then
        table.insert(self.edges, {
          from=from, to=to, type=ed.type,
          label=ed.label, offset=math.random()*100, hover=false,
        })
      end
    end
  end
end

-- ─── Update ──────────────────────────────────────────────────────────

function NetworkUI:update(dt)
  self.timer = self.timer + dt

  -- Reveal animasyonu
  self._reveal_timer = self._reveal_timer + dt
  for _, item in ipairs(self._reveal_queue) do
    if self._reveal_timer >= item.delay then
      item.node.reveal = math.min(1, item.node.reveal + dt / REVEAL_DUR)
    end
  end
end

-- ─── Pozisyon hesaplama ───────────────────────────────────────────────

function NetworkUI:_calcPositions(x, y, w, h)
  self._cx, self._cy = x, y
  self._w,  self._h  = w, h
  -- Pad: düğümlerin çerçeve dışına taşmaması için
  local pad = NODE_R + 10
  for _, nd in ipairs(self.nodes) do
    nd.x = x + pad + nd.nx * (w - pad*2)
    nd.y = y + pad + nd.ny * (h - pad*2)
  end
end

-- ─── Draw ────────────────────────────────────────────────────────────

function NetworkUI:draw(x, y, w, h)
  self:_calcPositions(x, y, w, h)

  -- Arka plan
  love.graphics.setColor(0.04, 0.04, 0.03, 1)
  love.graphics.rectangle("fill", x, y, w, h)

  -- Izgara (çok hafif)
  love.graphics.setColor(0.12, 0.11, 0.09, 0.5)
  love.graphics.setLineWidth(0.3)
  local gs = 40
  for gx = x, x+w, gs do love.graphics.line(gx, y, gx, y+h) end
  for gy = y, y+h, gs do love.graphics.line(x, gy, x+w, gy) end

  -- Kenarlar (önce, düğümlerin altında kalır)
  for _, ed in ipairs(self.edges) do
    self:_drawEdge(ed)
  end

  -- Düğümler
  for _, nd in ipairs(self.nodes) do
    self:_drawNode(nd)
  end

  -- Detay paneli (seçili düğüm)
  if self.selected_node then
    self:_drawDetailPanel(self.selected_node, x, y, w, h)
  end

  -- Kenar tooltip (hover)
  if self.hover_edge and not self.selected_node then
    self:_drawEdgeTooltip(self.hover_edge, x, y, w, h)
  end

  -- Başlık
  love.graphics.setFont(self.f_title)
  love.graphics.setColor(0.82, 0.77, 0.62, 0.9)
  love.graphics.print(self.title, x + 14, y + 12)

  -- İstatistik (sağ üst)
  love.graphics.setFont(self.f_label)
  love.graphics.setColor(0.38, 0.35, 0.28, 0.8)
  local stat = #self.nodes .. " aktör · " .. #self.edges .. " bağlantı"
  love.graphics.print(stat, x + w - self.f_label:getWidth(stat) - 12, y + 15)

  love.graphics.setLineWidth(1)
  love.graphics.setColor(1,1,1,1)
end

-- ─── Kenar çizimi ────────────────────────────────────────────────────

function NetworkUI:_drawEdge(ed)
  local fn = ed.from
  local tn = ed.to
  if fn.reveal < 0.01 or tn.reveal < 0.01 then return end

  local col = NetworkData.EDGE_COLORS[ed.type] or {0.5,0.5,0.5}
  local cr, cg, cb = col[1], col[2], col[3]

  -- Kenar opaklığı: her iki düğümün reveal değerinin miniması
  local alpha = math.min(fn.reveal, tn.reveal)

  -- Ok yönü: fn → tn vektörü
  local dx = tn.x - fn.x
  local dy = tn.y - fn.y
  local dist = math.sqrt(dx*dx + dy*dy)
  if dist < 1 then return end
  local ux, uy = dx/dist, dy/dist

  -- Düğüm yüzeyinden başla/bitir
  local r_from = fn.type == "victim" and NODE_R_VICTIM or NODE_R
  local r_to   = tn.type == "victim" and NODE_R_VICTIM or NODE_R
  local x1 = fn.x + ux * r_from
  local y1 = fn.y + uy * r_from
  local x2 = tn.x - ux * r_to
  local y2 = tn.y - uy * r_to

  -- Animasyonlu kesikli çizgi (akan akış hissi)
  local anim_offset = (self.timer * EDGE_SPEED + ed.offset) % 24
  love.graphics.setColor(cr, cg, cb, 0.22 * alpha)
  love.graphics.setLineWidth(1.5)
  love.graphics.line(x1, y1, x2, y2)

  -- Akan dash efekti (segment bazlı simülasyon)
  love.graphics.setColor(cr, cg, cb, (ed.hover and 0.95 or 0.55) * alpha)
  love.graphics.setLineWidth(ed.hover and 2 or 1.2)
  local dash_len = 10
  local gap_len  = 14
  local period   = dash_len + gap_len
  local travelled = 0
  local total_len = math.sqrt((x2-x1)^2 + (y2-y1)^2)
  local px_x, px_y = x1, y1

  while travelled < total_len do
    local phase_in_period = (travelled + anim_offset) % period
    if phase_in_period < dash_len then
      local seg_end = math.min(total_len, travelled + (dash_len - phase_in_period))
      local t1 = travelled / total_len
      local t2 = seg_end  / total_len
      love.graphics.line(
        x1 + (x2-x1)*t1, y1 + (y2-y1)*t1,
        x1 + (x2-x1)*t2, y1 + (y2-y1)*t2
      )
      travelled = seg_end
    else
      travelled = travelled + (period - phase_in_period)
    end
  end

  -- Ok başı
  local arrow_size = 7
  local ax = x2
  local ay = y2
  local perp_x, perp_y = -uy * 0.45, ux * 0.45
  love.graphics.setColor(cr, cg, cb, (ed.hover and 1 or 0.7) * alpha)
  love.graphics.setLineWidth(1)
  love.graphics.line(
    ax, ay,
    ax - ux*arrow_size + perp_x*arrow_size,
    ay - uy*arrow_size + perp_y*arrow_size
  )
  love.graphics.line(
    ax, ay,
    ax - ux*arrow_size - perp_x*arrow_size,
    ay - uy*arrow_size - perp_y*arrow_size
  )
end

-- ─── Düğüm çizimi ────────────────────────────────────────────────────

function NetworkUI:_drawNode(nd)
  if nd.reveal < 0.01 then return end

  local r    = (nd.type == "victim") and NODE_R_VICTIM or NODE_R
  r          = r * nd.reveal    -- reveal animasyonu boyutu
  local col  = NetworkData.TYPE_COLORS[nd.type] or {0.6,0.6,0.6}
  local cr, cg, cb = col[1], col[2], col[3]

  local is_sel   = self.selected_node == nd
  local is_hover = nd.hover

  -- Seçim halesi
  if is_sel then
    love.graphics.setColor(cr, cg, cb, 0.18)
    love.graphics.circle("fill", nd.x, nd.y, r + 10 + math.sin(self.timer*3)*3)
    love.graphics.setColor(cr, cg, cb, 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", nd.x, nd.y, r + 10)
  end

  -- Hover ışıması
  if is_hover and not is_sel then
    love.graphics.setColor(cr, cg, cb, 0.12)
    love.graphics.circle("fill", nd.x, nd.y, r + 7)
  end

  -- Dış halka (mağdur için vurgulu)
  local ring_a = nd.type == "victim" and 0.8 or 0.45
  love.graphics.setColor(cr, cg, cb, ring_a * nd.reveal)
  love.graphics.setLineWidth(nd.type == "victim" and 1.5 or 0.8)
  love.graphics.circle("line", nd.x, nd.y, r)

  -- Dolgu
  local fill_a = nd.type == "victim" and 0.12 or 0.18
  love.graphics.setColor(cr, cg, cb, fill_a * nd.reveal)
  love.graphics.circle("fill", nd.x, nd.y, r)

  -- İç parlama (küçük)
  love.graphics.setColor(1, 1, 1, 0.20 * nd.reveal)
  love.graphics.circle("fill", nd.x - r*0.2, nd.y - r*0.2, r*0.28)

  -- Tip ikonu (küçük harf kodu, merkez)
  local type_icons = {
    state   = "D",  corp    = "Ş",  finance = "₺",
    media   = "M",  law     = "⚖",  tech    = "⚙",
    ngo     = "N",  victim  = "●",
  }
  local icon = type_icons[nd.type] or "?"
  love.graphics.setFont(self.f_type)
  love.graphics.setColor(cr, cg, cb, 0.85 * nd.reveal)
  local iw = self.f_type:getWidth(icon)
  love.graphics.print(icon, nd.x - iw/2, nd.y - 6)

  -- Etiket (altında)
  love.graphics.setFont(self.f_node)
  love.graphics.setColor(0.80, 0.76, 0.62, 0.9 * nd.reveal)
  local lw  = self.f_node:getWidth(nd.label)
  local lx  = nd.x - lw/2
  local ly  = nd.y + r + 3

  -- Etiket arka plan
  love.graphics.setColor(0.04, 0.03, 0.03, 0.75 * nd.reveal)
  love.graphics.rectangle("fill", lx - 3, ly - 1, lw + 6, 12, 2)

  love.graphics.setColor(0.82, 0.78, 0.64, nd.reveal)
  love.graphics.print(nd.label, lx, ly)

  love.graphics.setLineWidth(1)
end

-- ─── Detay Paneli ────────────────────────────────────────────────────

function NetworkUI:_drawDetailPanel(nd, x, y, w, h)
  local col  = NetworkData.TYPE_COLORS[nd.type] or {0.6,0.6,0.6}
  local cr, cg, cb = col[1], col[2], col[3]

  local pw, ph = 220, 160
  -- Panel konumunu düğümün yanında hesapla
  local px = nd.x + NODE_R + 12
  if px + pw > x + w - 10 then px = nd.x - pw - NODE_R - 12 end
  local py = nd.y - 20
  if py + ph > y + h - 10 then py = y + h - ph - 10 end
  if py < y + 10 then py = y + 10 end

  -- Panel arka plan
  love.graphics.setColor(0.06, 0.05, 0.04, 0.96)
  love.graphics.rectangle("fill", px, py, pw, ph, 6)
  love.graphics.setColor(cr, cg, cb, 0.6)
  love.graphics.rectangle("fill", px, py, 3, ph, 2)
  love.graphics.setColor(cr, cg, cb, 0.22)
  love.graphics.setLineWidth(0.5)
  love.graphics.rectangle("line", px, py, pw, ph, 6)

  -- Başlık
  love.graphics.setFont(self.f_detail)
  love.graphics.setColor(0.88, 0.83, 0.70, 1)
  love.graphics.printf(nd.label, px+10, py+10, pw-20, "left")

  -- Tip etiketi
  local type_names = {
    state="Devlet", corp="Şirket", finance="Finans", media="Medya",
    law="Hukuki Kurum", tech="Teknoloji", ngo="Örgüt", victim="Mağdur Taraf",
  }
  love.graphics.setFont(self.f_label)
  love.graphics.setColor(cr, cg, cb, 0.8)
  love.graphics.print(type_names[nd.type] or nd.type, px+10, py+34)

  -- Bu düğüme gelen / giden kenarlar
  love.graphics.setColor(0.22, 0.20, 0.16, 1)
  love.graphics.setLineWidth(0.5)
  love.graphics.line(px+8, py+54, px+pw-8, py+54)

  love.graphics.setFont(self.f_node)
  local ly2 = py + 62
  local count = 0
  for _, ed in ipairs(self.edges) do
    if (ed.from == nd or ed.to == nd) and count < 5 then
      local other = ed.from == nd and ed.to or ed.from
      local arrow = ed.from == nd and "→" or "←"
      local ec    = NetworkData.EDGE_COLORS[ed.type] or {0.5,0.5,0.5}
      love.graphics.setColor(ec[1], ec[2], ec[3], 0.8)
      local conn_text = arrow .. " " .. other.label
      love.graphics.print(conn_text, px+10, ly2)
      ly2   = ly2 + 14
      count = count + 1
    end
  end

  if count == 0 then
    love.graphics.setColor(0.35, 0.32, 0.26, 0.7)
    love.graphics.print("Bağlantı bulunamadı", px+10, ly2)
  end

  -- Kapat ipucu
  love.graphics.setColor(0.35, 0.32, 0.26, 0.6)
  love.graphics.print("[ tekrar tıkla = kapat ]", px+10, py+ph-18)

  love.graphics.setLineWidth(1)
end

-- ─── Kenar Tooltip ───────────────────────────────────────────────────

function NetworkUI:_drawEdgeTooltip(ed, x, y, w, h)
  local col  = NetworkData.EDGE_COLORS[ed.type] or {0.6,0.6,0.6}
  local cr, cg, cb = col[1], col[2], col[3]

  -- Kenar orta noktası
  local mx = (ed.from.x + ed.to.x) / 2
  local my = (ed.from.y + ed.to.y) / 2

  local tw, th = TOOLTIP_W, 68
  local tx = math.max(x+8, math.min(mx - tw/2, x+w-tw-8))
  local ty = math.max(y+8, my - th - 12)

  love.graphics.setColor(0.06, 0.05, 0.04, 0.94)
  love.graphics.rectangle("fill", tx, ty, tw, th, 5)
  love.graphics.setColor(cr, cg, cb, 0.55)
  love.graphics.setLineWidth(0.5)
  love.graphics.rectangle("line", tx, ty, tw, th, 5)

  local type_names = {
    arms="Silah Tedariki", finance="Finansal Destek", veto="Hukuki Veto",
    silence="Medya Suskunluğu", tech="Teknoloji Transferi",
    sanction="Yaptırım / Baskı", aid="Yardım Engeli", lobby="Lobi",
  }

  love.graphics.setFont(self.f_label)
  love.graphics.setColor(cr, cg, cb, 0.9)
  love.graphics.print(type_names[ed.type] or ed.type, tx+10, ty+10)

  love.graphics.setFont(self.f_node)
  love.graphics.setColor(0.72, 0.68, 0.56, 0.9)
  love.graphics.printf(ed.label or "", tx+10, ty+28, tw-20, "left")

  -- Kaynak → hedef
  love.graphics.setColor(0.42, 0.39, 0.31, 0.8)
  love.graphics.print(ed.from.label .. " → " .. ed.to.label, tx+10, ty+50)

  love.graphics.setLineWidth(1)
end

-- ─── Hover Tespiti ───────────────────────────────────────────────────

function NetworkUI:updateHover(mx, my)
  -- Düğüm hover
  for _, nd in ipairs(self.nodes) do
    local r = (nd.type == "victim") and NODE_R_VICTIM or NODE_R
    local dx, dy = mx - nd.x, my - nd.y
    nd.hover = (dx*dx + dy*dy <= r*r) and nd.reveal > 0.5
  end

  -- Kenar hover (orta nokta yakınlık kontrolü)
  self.hover_edge = nil
  for _, ed in ipairs(self.edges) do
    ed.hover = false
    if ed.from.reveal > 0.5 and ed.to.reveal > 0.5 then
      -- Noktanın çizgiye mesafesi
      local ax, ay = ed.from.x, ed.from.y
      local bx, by = ed.to.x,   ed.to.y
      local dist   = self:_ptLineDist(mx, my, ax, ay, bx, by)
      if dist < 10 then
        ed.hover       = true
        self.hover_edge = ed
      end
    end
  end
end

function NetworkUI:_ptLineDist(px, py, ax, ay, bx, by)
  local dx, dy = bx-ax, by-ay
  local len2   = dx*dx + dy*dy
  if len2 < 1 then return math.sqrt((px-ax)^2+(py-ay)^2) end
  local t = ((px-ax)*dx + (py-ay)*dy) / len2
  t = math.max(0, math.min(1, t))
  local cx2, cy2 = ax + t*dx, ay + t*dy
  return math.sqrt((px-cx2)^2 + (py-cy2)^2)
end

-- ─── Girdi ───────────────────────────────────────────────────────────

function NetworkUI:mousepressed(mx, my)
  self:_handlePress(mx, my)
end

function NetworkUI:touchpressed(id, mx, my)
  self:_handlePress(mx, my)
end

function NetworkUI:_handlePress(mx, my)
  for _, nd in ipairs(self.nodes) do
    local r  = (nd.type == "victim") and NODE_R_VICTIM or NODE_R
    local dx, dy = mx - nd.x, my - nd.y
    if dx*dx + dy*dy <= (r+4)^2 and nd.reveal > 0.5 then
      if self.selected_node == nd then
        self.selected_node = nil
      else
        self.selected_node = nd
      end
      return
    end
  end
  -- Boş alana tıkla → seçimi kaldır
  self.selected_node = nil
end

return NetworkUI
