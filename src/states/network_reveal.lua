--[[
  NetworkRevealState — Sinematik Zulüm Ağı Açılış Sahnesi
  
  ActState, anlatıda "network_reveal" tipinde bir node ile karşılaştığında
  StateManager.push("network_reveal", payload) çağırır.
  
  Payload yapısı:
  {
    region_id       = "gaza",
    level           = 2,
    highlight_nodes = { "usa", "boeing", "israel" },   -- vurgulanan aktörler
    highlight_edges = { "usa→israel", "boeing→israel" }, -- vurgulanan bağlar
    caption_key     = "gaza.act2.network_caption",     -- açıklama metni
    caption_text    = "...",                           -- veya doğrudan metin
    next_cb         = function() ... end               -- geri dönüşte çağrılacak
  }
  
  Akış:
    1. Ekran kararır (fade-to-black), gerilim sesi
    2. "// ZULÜM AĞI AÇILIYOR" başlığı belirir
    3. Düğümler sırayla pulse ile açılır
    4. Highlight'lı düğümler kırmızı nabız atar + açıklama baloncuğu
    5. Bağlantılar akan çizgi ile belirir
    6. Anlatıcı açıklama metni alt bölmede gösterilir (typewriter)
    7. "Devam" butonuyla narrative'e geri dön → StateManager.pop()
--]]

local StateManager  = require("src.systems.state_manager")
local NetworkUI     = require("src.ui.network_ui")
local NetworkData   = require("src.systems.network_data")
local AudioManager  = require("src.systems.audio_manager")
local I18n          = require("src.systems.i18n")
local Config        = require("src.utils.config")

local NetworkRevealState = {}
NetworkRevealState.__index = NetworkRevealState

-- ─── Aşamalar ────────────────────────────────────────────────────────
local PHASE = {
  FADE_IN       = 1,   -- 0.8 sn: ekran kararır
  TITLE         = 2,   -- 1.2 sn: başlık belirir
  BUILD_NODES   = 3,   -- düğümler sırayla açılır
  BUILD_EDGES   = 4,   -- kenarlar akan çizgiyle
  HIGHLIGHT     = 5,   -- vurgulanan düğümler pulse
  CAPTION       = 6,   -- typewriter açıklama
  IDLE          = 7,   -- okuyucu bekler, devam butonu aktif
}

local PHASE_DUR = {
  [PHASE.FADE_IN]    = 0.7,
  [PHASE.TITLE]      = 1.0,
  [PHASE.BUILD_NODES]= 0,   -- dinamik (düğüm sayısı × 0.18)
  [PHASE.BUILD_EDGES]= 0,   -- dinamik
  [PHASE.HIGHLIGHT]  = 1.2,
  [PHASE.CAPTION]    = 0,   -- typewriter hızına bağlı
  [PHASE.IDLE]       = 999,
}

local CAPTION_SPEED = 38   -- karakter/sn

function NetworkRevealState.new()
  return setmetatable({}, NetworkRevealState)
end

function NetworkRevealState:enter(data)
  data = data or {}

  self.region_id       = data.region_id or "gaza"
  self.level           = data.level     or 0
  self.highlight_nodes = data.highlight_nodes or {}
  self.highlight_edges = data.highlight_edges or {}
  self.caption_text    = data.caption_text
  if not self.caption_text and data.caption_key then
    self.caption_text = I18n.t(data.caption_key)
    if self.caption_text:sub(1,1) == "[" then
      self.caption_text = nil
    end
  end
  self.next_cb = data.next_cb

  -- Highlight setleri (hızlı arama için)
  self._hl_nodes = {}
  for _, id in ipairs(self.highlight_nodes) do self._hl_nodes[id] = true end
  self._hl_edges = {}
  for _, key in ipairs(self.highlight_edges) do self._hl_edges[key] = true end

  -- Durum
  self.timer      = 0
  self.phase      = PHASE.FADE_IN
  self.phase_t    = 0
  self.overlay_a  = 1.0   -- genel overlay opaklığı (1=tam siyah, 0=şeffaf)

  -- Fontlar
  self.f_header  = love.graphics.newFont(20)
  self.f_mono    = love.graphics.newFont(11)
  self.f_caption = love.graphics.newFont(16)
  self.f_small   = love.graphics.newFont(12)
  self.f_cont    = love.graphics.newFont(14)

  -- Ağ verisi
  local net_raw = NetworkData.getUnlocked(self.region_id, self.level)
  self.nodes = net_raw and net_raw.nodes or {}
  self.edges = net_raw and net_raw.edges or {}
  self.net_title = net_raw and net_raw.title or ""

  -- Düğüm haritası (id → node)
  self.node_map = {}
  for _, nd in ipairs(self.nodes) do
    nd._reveal   = 0
    nd._pulse    = 0
    nd._shown    = false
    self.node_map[nd.id] = nd
  end
  -- Kenar hazırlık
  for _, ed in ipairs(self.edges) do
    ed._reveal  = 0
    ed._offset  = math.random() * 80
    ed._shown   = false
    ed._hl      = self._hl_edges[ed.from .. "→" .. ed.to] or
                  self._hl_edges[ed.from .. "_" .. ed.to]
  end

  -- Açılış sırası
  self._node_queue = {}   -- { node, delay }
  self._edge_queue = {}

  -- Vurgulananları öne al
  local function is_hl(nd) return self._hl_nodes[nd.id] end
  local delay = 0
  local STEP  = 0.20

  -- Önce normal düğümler, sonra highlight
  for _, nd in ipairs(self.nodes) do
    if not is_hl(nd) then
      table.insert(self._node_queue, { node=nd, delay=delay })
      delay = delay + STEP * 0.6
    end
  end
  for _, nd in ipairs(self.nodes) do
    if is_hl(nd) then
      table.insert(self._node_queue, { node=nd, delay=delay })
      delay = delay + STEP
    end
  end
  PHASE_DUR[PHASE.BUILD_NODES] = delay + 0.3

  -- Kenar kuyruğu
  delay = 0
  for _, ed in ipairs(self.edges) do
    table.insert(self._edge_queue, { edge=ed, delay=delay })
    delay = delay + 0.10
  end
  PHASE_DUR[PHASE.BUILD_EDGES] = delay + 0.4

  -- Caption
  self._caption_shown  = ""
  self._caption_full   = self.caption_text or
    "Bu ağ gerçek belgelere dayanmaktadır.\nKaynaklar: SIPRI · BM Kayıtları · Amnesty International"
  self._caption_index  = 0
  self._caption_timer  = 0
  self._caption_done   = false
  PHASE_DUR[PHASE.CAPTION] = (#self._caption_full / CAPTION_SPEED) + 0.5

  -- Devam butonu
  self._cont_btn = nil   -- draw'da hesaplanır
  self._cont_hot = false

  -- Ses
  AudioManager.playSFX("tension", 0.8)

  -- Viewport
  local W, H = Config.vw(), Config.vh()
  self._net_x  = 60
  self._net_y  = 80
  self._net_w  = W - 120
  self._net_h  = H - 200
end

-- ─── Update ──────────────────────────────────────────────────────────

function NetworkRevealState:update(dt)
  self.timer   = self.timer + dt
  self.phase_t = self.phase_t + dt

  self:_updatePhase(dt)
  self:_updateNodes(dt)
  self:_updateEdges(dt)
  self:_updateCaption(dt)

  -- Hover: devam butonu
  if self.phase == PHASE.IDLE and self._cont_btn then
    local mx, my = Config.toLogical(love.mouse.getPosition())
    local b = self._cont_btn
    self._cont_hot = mx >= b.x and mx <= b.x+b.w and
                     my >= b.y and my <= b.y+b.h
  end
end

function NetworkRevealState:_updatePhase(dt)
  local dur = PHASE_DUR[self.phase] or 1

  if self.phase == PHASE.FADE_IN then
    local p = math.min(1, self.phase_t / dur)
    -- Overlay 1→0.85 (tam siyahtan derin karanlığa)
    self.overlay_a = 1.0 - p * 0.15
    if self.phase_t >= dur then self:_nextPhase() end

  elseif self.phase == PHASE.TITLE then
    self.overlay_a = 0.85
    if self.phase_t >= dur then self:_nextPhase() end

  elseif self.phase == PHASE.BUILD_NODES then
    self.overlay_a = 0.85
    local t = self.phase_t
    for _, item in ipairs(self._node_queue) do
      if t >= item.delay and not item.node._shown then
        item.node._shown = true
        -- Highlight node için ayrı ses
        if self._hl_nodes[item.node.id] then
          AudioManager.playSFX("tension", 0.3)
        end
      end
    end
    if self.phase_t >= PHASE_DUR[PHASE.BUILD_NODES] then self:_nextPhase() end

  elseif self.phase == PHASE.BUILD_EDGES then
    self.overlay_a = 0.82
    local t = self.phase_t
    for _, item in ipairs(self._edge_queue) do
      if t >= item.delay and not item.edge._shown then
        item.edge._shown = true
      end
    end
    if self.phase_t >= PHASE_DUR[PHASE.BUILD_EDGES] then self:_nextPhase() end

  elseif self.phase == PHASE.HIGHLIGHT then
    self.overlay_a = 0.78
    if self.phase_t >= PHASE_DUR[PHASE.HIGHLIGHT] then
      AudioManager.playSFX("weighted_moment", 0.65)
      self:_nextPhase()
    end

  elseif self.phase == PHASE.CAPTION then
    self.overlay_a = 0.72
    if self._caption_done and self.phase_t >= PHASE_DUR[PHASE.CAPTION] then
      self:_nextPhase()
    end

  elseif self.phase == PHASE.IDLE then
    self.overlay_a = 0.68
  end
end

function NetworkRevealState:_nextPhase()
  self.phase   = self.phase + 1
  self.phase_t = 0
end

function NetworkRevealState:_updateNodes(dt)
  local reveal_speed = 3.5
  for _, nd in ipairs(self.nodes) do
    if nd._shown then
      nd._reveal = math.min(1, nd._reveal + dt * reveal_speed)
    end
    -- Pulse (highlight düğümler için)
    if self._hl_nodes[nd.id] and nd._reveal > 0.5 then
      nd._pulse = self.timer
    end
  end
end

function NetworkRevealState:_updateEdges(dt)
  for _, ed in ipairs(self.edges) do
    if ed._shown then
      ed._reveal = math.min(1, ed._reveal + dt * 2.5)
    end
  end
end

function NetworkRevealState:_updateCaption(dt)
  if self.phase < PHASE.CAPTION then return end
  if self._caption_done then return end

  self._caption_timer = self._caption_timer + dt

  -- UTF-8 güvenli karakter sayısı (Lua 5.1)
  local function u8len(s)
    local c = 0
    for i = 1, #s do
      local b = s:byte(i)
      if b < 0x80 or b >= 0xC0 then c = c + 1 end
    end
    return c
  end
  local function u8sub(s, n)
    if n <= 0 then return "" end
    local c = 0
    for i = 1, #s do
      local b = s:byte(i)
      if b < 0x80 or b >= 0xC0 then
        c = c + 1
        if c > n then return s:sub(1, i - 1) end
      end
    end
    return s
  end

  local char_count = u8len(self._caption_full)
  local new_char   = math.min(math.floor(self._caption_timer * CAPTION_SPEED), char_count)

  if new_char > self._caption_index and new_char % 4 == 0 then
    AudioManager.playSFX("typewriter", 0.18)
  end

  self._caption_index = new_char

  if new_char >= char_count then
    self._caption_shown = self._caption_full
    self._caption_done  = true
  else
    self._caption_shown = u8sub(self._caption_full, new_char)
  end
end

-- ─── Draw ────────────────────────────────────────────────────────────

function NetworkRevealState:draw()
  local W, H = Config.vw(), Config.vh()
  local nx, ny = self._net_x, self._net_y
  local nw, nh = self._net_w, self._net_h

  -- Koyu overlay
  love.graphics.setColor(0.03, 0.02, 0.02, self.overlay_a)
  love.graphics.rectangle("fill", 0, 0, W, H)

  -- ① Ağ (özel reveal renderer ile)
  self:_drawRevealNetwork(nx, ny, nw, nh)

  -- ② Başlık (TITLE aşamasından itibaren)
  if self.phase >= PHASE.TITLE then
    self:_drawRevealHeader(W)
  end

  -- ③ Caption bölmesi
  if self.phase >= PHASE.CAPTION then
    self:_drawCaption(W, H)
  end

  -- ④ Devam butonu (IDLE aşamasında)
  if self.phase == PHASE.IDLE then
    self:_drawContinueBtn(W, H)
  end

  love.graphics.setColor(1,1,1,1)
  love.graphics.setLineWidth(1)
end

function NetworkRevealState:_drawRevealHeader(W)
  -- "// ZULÜM AĞI AÇILIYOR" başlığı
  local header_a = math.min(1, self.phase_t / 0.5)
  love.graphics.setFont(self.f_mono)
  love.graphics.setColor(0.75, 0.25, 0.18, 0.7 * header_a)
  local hdr1 = "// ZULÜM AĞI — İFŞA SEVİYESİ " .. tostring(self.level)
  love.graphics.print(hdr1, 20, 14)

  love.graphics.setFont(self.f_header)
  love.graphics.setColor(0.85, 0.78, 0.60, 0.9 * header_a)
  love.graphics.print(self.net_title, 20, 30)

  -- Pulsing "CANLI" göstergesi
  if self.phase >= PHASE.BUILD_NODES then
    local blink = (math.sin(self.timer * 3) + 1) / 2
    love.graphics.setFont(self.f_mono)
    love.graphics.setColor(0.80, 0.22, 0.18, blink * 0.9)
    love.graphics.print("● CANLI", Config.vw() - 90, 20)
  end
end

function NetworkRevealState:_drawRevealNetwork(nx, ny, nw, nh)
  -- Çerçeve
  love.graphics.setColor(0.20, 0.17, 0.13, 0.6)
  love.graphics.setLineWidth(0.5)
  love.graphics.rectangle("line", nx, ny, nw, nh, 4)

  -- Hafif ızgara
  love.graphics.setColor(0.10, 0.09, 0.07, 0.5)
  love.graphics.setLineWidth(0.3)
  local gs = 50
  for gx = nx, nx+nw, gs do love.graphics.line(gx, ny, gx, ny+nh) end
  for gy = ny, ny+nh, gs do love.graphics.line(nx, gy, nx+nw, gy) end

  -- Düğüm pozisyonları
  local pad = 24
  for _, nd in ipairs(self.nodes) do
    nd._rx = nx + pad + nd.x * (nw - pad*2)
    nd._ry = ny + pad + nd.y * (nh - pad*2)
  end

  -- Kenarlar
  for _, ed in ipairs(self.edges) do
    if ed._reveal > 0.01 then
      self:_drawRevealEdge(ed)
    end
  end

  -- Düğümler
  for _, nd in ipairs(self.nodes) do
    if nd._reveal > 0.01 then
      self:_drawRevealNode(nd)
    end
  end
end

function NetworkRevealState:_drawRevealNode(nd)
  local r   = 14 * nd._reveal
  local col = NetworkData.TYPE_COLORS[nd.type] or {0.5,0.5,0.5}
  local cr, cg, cb = col[1], col[2], col[3]
  local is_hl = self._hl_nodes[nd.id]

  if is_hl and nd._reveal > 0.5 then
    -- Kırmızı nabız halkası
    local pulse = (math.sin(self.timer * 4) + 1) / 2
    love.graphics.setColor(0.85, 0.20, 0.15, 0.15 + pulse * 0.25)
    love.graphics.circle("fill", nd._rx, nd._ry, r + 14 + pulse * 8)
    love.graphics.setColor(0.85, 0.20, 0.15, 0.6 + pulse * 0.3)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", nd._rx, nd._ry, r + 7 + pulse * 4)

    -- Parlak kırmızı dış çizgi override
    cr, cg, cb = 0.90 + pulse*0.08, 0.25 + pulse*0.1, 0.18
  end

  -- Dolgu
  love.graphics.setColor(cr, cg, cb, 0.18 * nd._reveal)
  love.graphics.circle("fill", nd._rx, nd._ry, r)

  -- Çerçeve
  love.graphics.setColor(cr, cg, cb, (is_hl and 0.95 or 0.55) * nd._reveal)
  love.graphics.setLineWidth(is_hl and 1.5 or 0.8)
  love.graphics.circle("line", nd._rx, nd._ry, r)

  -- Etiket
  love.graphics.setFont(self.f_small)
  local lw  = self.f_small:getWidth(nd.label)
  local lx  = nd._rx - lw/2
  local ly  = nd._ry + r + 3

  -- Etiket arka plan
  love.graphics.setColor(0.03, 0.02, 0.02, 0.80 * nd._reveal)
  love.graphics.rectangle("fill", lx-3, ly-1, lw+6, 13, 2)

  -- Highlight etiket: parlak sarı
  if is_hl and nd._reveal > 0.5 then
    local pulse = (math.sin(self.timer * 4) + 1) / 2
    love.graphics.setColor(1.0, 0.85 + pulse*0.1, 0.30, nd._reveal)
  else
    love.graphics.setColor(0.78, 0.74, 0.60, 0.9 * nd._reveal)
  end
  love.graphics.print(nd.label, lx, ly)

  -- Highlight badge: "!" işareti
  if is_hl and nd._reveal > 0.7 then
    love.graphics.setFont(self.f_mono)
    love.graphics.setColor(0.90, 0.25, 0.18, 0.9)
    love.graphics.print("!", nd._rx - 3, nd._ry - 8)
  end

  love.graphics.setLineWidth(1)
end

function NetworkRevealState:_drawRevealEdge(ed)
  local fn = self.node_map[ed.from]
  local tn = self.node_map[ed.to]
  if not fn or not tn then return end
  if fn._reveal < 0.2 or tn._reveal < 0.2 then return end

  local col = NetworkData.EDGE_COLORS[ed.type] or {0.5,0.5,0.5}
  local cr, cg, cb = col[1], col[2], col[3]
  local is_hl = ed._hl

  local alpha = ed._reveal * math.min(fn._reveal, tn._reveal)

  local dx = tn._rx - fn._rx
  local dy = tn._ry - fn._ry
  local dist = math.sqrt(dx*dx + dy*dy)
  if dist < 1 then return end
  local ux, uy = dx/dist, dy/dist

  local r_from = 14 * fn._reveal
  local r_to   = 14 * tn._reveal
  local x1 = fn._rx + ux * r_from
  local y1 = fn._ry + uy * r_from
  local x2 = tn._rx - ux * r_to
  local y2 = tn._ry - uy * r_to

  -- Highlight kenarlar: kırmızıya çek + daha kalın
  if is_hl then
    cr = cr * 0.4 + 0.6
    cg = cg * 0.3
    cb = cb * 0.3
  end

  -- Gölge çizgi
  love.graphics.setColor(cr, cg, cb, 0.15 * alpha)
  love.graphics.setLineWidth(is_hl and 3 or 1.5)
  love.graphics.line(x1, y1, x2, y2)

  -- Akan dash
  local speed = is_hl and 60 or 40
  local anim  = (self.timer * speed + ed._offset) % 24
  love.graphics.setColor(cr, cg, cb, (is_hl and 0.85 or 0.55) * alpha)
  love.graphics.setLineWidth(is_hl and 2 or 1)

  local dash_len, gap_len = 10, 14
  local period = dash_len + gap_len
  local total_len = math.sqrt((x2-x1)^2+(y2-y1)^2)
  local travelled = 0

  while travelled < total_len do
    local phase = (travelled + anim) % period
    if phase < dash_len then
      local seg_end = math.min(total_len, travelled + (dash_len - phase))
      local t1 = travelled / total_len
      local t2 = seg_end  / total_len
      love.graphics.line(
        x1+(x2-x1)*t1, y1+(y2-y1)*t1,
        x1+(x2-x1)*t2, y1+(y2-y1)*t2
      )
      travelled = seg_end
    else
      travelled = travelled + (period - phase)
    end
  end

  -- Ok başı
  local as = is_hl and 9 or 7
  local px2, py2 = -uy*0.45, ux*0.45
  love.graphics.setColor(cr, cg, cb, (is_hl and 1 or 0.7) * alpha)
  love.graphics.setLineWidth(is_hl and 1.5 or 1)
  love.graphics.line(x2, y2, x2-ux*as+px2*as, y2-uy*as+py2*as)
  love.graphics.line(x2, y2, x2-ux*as-px2*as, y2-uy*as-py2*as)

  love.graphics.setLineWidth(1)
end

function NetworkRevealState:_drawCaption(W, H)
  local cap_h = 88
  local cap_y = H - cap_h - 10

  -- Caption kutusu
  love.graphics.setColor(0.04, 0.03, 0.02, 0.92)
  love.graphics.rectangle("fill", 16, cap_y, W-32, cap_h, 5)
  love.graphics.setColor(0.75, 0.25, 0.18, 0.4)
  love.graphics.setLineWidth(0.5)
  love.graphics.rectangle("line", 16, cap_y, W-32, cap_h, 5)
  love.graphics.rectangle("fill", 16, cap_y, 3, cap_h, 2)   -- sol kırmızı bant

  love.graphics.setFont(self.f_mono)
  love.graphics.setColor(0.65, 0.22, 0.16, 0.8)
  love.graphics.print("// ANLATİCİ", 28, cap_y + 10)

  love.graphics.setFont(self.f_caption)
  love.graphics.setColor(0.82, 0.78, 0.65, 1)
  love.graphics.printf(self._caption_shown, 28, cap_y + 28, W-60, "left")
end

function NetworkRevealState:_drawContinueBtn(W, H)
  local bw, bh = 200, 36
  local bx = W/2 - bw/2
  local by = H - 52

  self._cont_btn = {x=bx, y=by, w=bw, h=bh}

  local hot = self._cont_hot
  local pulse = (math.sin(self.timer * 2.5) + 1) / 2

  love.graphics.setColor(0.08, 0.07, 0.05, hot and 0.95 or 0.85)
  love.graphics.rectangle("fill", bx, by, bw, bh, 6)
  love.graphics.setColor(0.75, 0.62, 0.38,
    (hot and 0.9 or (0.4 + pulse * 0.3)))
  love.graphics.setLineWidth(hot and 1.2 or 0.5)
  love.graphics.rectangle("line", bx, by, bw, bh, 6)

  love.graphics.setFont(self.f_cont)
  love.graphics.setColor(hot and 0.95 or 0.78,
                          hot and 0.90 or 0.73,
                          hot and 0.72 or 0.56, 1)
  local lbl = "Anlatıya Devam Et  →"
  local lw  = self.f_cont:getWidth(lbl)
  love.graphics.print(lbl, bx + bw/2 - lw/2, by + bh/2 - 7)
end

-- ─── Girdi ───────────────────────────────────────────────────────────

function NetworkRevealState:mousepressed(x, y, btn)
  if btn ~= 1 then return end
  self:_handlePress(x, y)
end

function NetworkRevealState:touchpressed(id, x, y, p)
  self:_handlePress(x, y)
end

function NetworkRevealState:_handlePress(x, y)
  -- Herhangi bir aşamada tıklama caption'ı hızlandırır
  if self.phase == PHASE.CAPTION and not self._caption_done then
    self._caption_shown = self._caption_full
    self._caption_index = #self._caption_full
    self._caption_done  = true
    return
  end

  -- IDLE aşamasında devam butonu
  if self.phase == PHASE.IDLE then
    local b = self._cont_btn
    if b and x >= b.x and x <= b.x+b.w and y >= b.y and y <= b.y+b.h then
      self:_finish()
    end
  end
end

function NetworkRevealState:keypressed(key)
  if key == "space" or key == "return" then
    if self.phase == PHASE.CAPTION and not self._caption_done then
      self._caption_shown = self._caption_full
      self._caption_index = #self._caption_full
      self._caption_done  = true
    elseif self.phase == PHASE.IDLE then
      self:_finish()
    end
  elseif key == "escape" then
    self:_finish()
  end
end

function NetworkRevealState:_finish()
  if self.next_cb then self.next_cb() end
  StateManager.pop()
end

-- Touch iletimi
function NetworkRevealState:touchpressed(id, x, y, p)
  self:_handlePress(x, y)
end
function NetworkRevealState:touchreleased(id, x, y, p) end
function NetworkRevealState:touchmoved(id, x, y, dx, dy, p) end

return NetworkRevealState
