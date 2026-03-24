--[[
  ActState — Diyalog & Karar Sahnesi (Balans Entegrasyonlu)
  
  Yeni özellikler:
    - Delta animasyonu: kaynak değişimleri HUD'da yukarı süzülür
    - Seçim ipuçları: hover'da tahmini etki sembolü (▲▼)
    - Kritik HUD: düşük kaynak kırmızı yanıp söner
    - Pasif drain: her node geçişinde görünür
--]]

local StateManager  = require("src.systems.state_manager")
local AudioManager  = require("src.systems.audio_manager")
local BalanceEngine = require("src.systems.balance_engine")
local BalanceCfg    = require("src.systems.balance_config")
local I18n          = require("src.systems.i18n")
local Config        = require("src.utils.config")

-- ─── Lua 5.1 uyumlu UTF-8 yardımcıları ────────────────────────────
-- LÖVE 11.x LuaJIT (Lua 5.1) kullanır, utf8 kütüphanesi yok.
-- UTF-8'de devam baytları 0x80-0xBF arasındadır.

local function utf8_len(s)
  local count = 0
  for i = 1, #s do
    local b = s:byte(i)
    if b < 0x80 or b >= 0xC0 then count = count + 1 end
  end
  return count
end

-- İlk n UTF-8 karakterini döndür
local function utf8_sub(s, n)
  if n <= 0 then return "" end
  local count = 0
  for i = 1, #s do
    local b = s:byte(i)
    if b < 0x80 or b >= 0xC0 then
      count = count + 1
      if count > n then return s:sub(1, i - 1) end
    end
  end
  return s
end

local ActState = {}
ActState.__index = ActState

local TYPEWRITER_SPEED    = 45
local TYPEWRITER_SFX_EVERY= 2

-- ─── Delta animasyon yöneticisi ──────────────────────────────────────

local DeltaAnim = {}
DeltaAnim.__index = DeltaAnim

function DeltaAnim.new()
  return setmetatable({ particles = {} }, DeltaAnim)
end

-- { key, value, x, y, age, duration, vy }
function DeltaAnim:spawn(key, value, hud_x, hud_y)
  if math.abs(value) < 0.5 then return end
  local cfg  = BalanceCfg.hud
  table.insert(self.particles, {
    key      = key,
    value    = value,
    x        = hud_x,
    y        = hud_y,
    age      = 0,
    duration = cfg.delta_show_duration,
    vy       = -cfg.delta_float_speed,
  })
end

function DeltaAnim:update(dt)
  local i = 1
  while i <= #self.particles do
    local p = self.particles[i]
    p.age = p.age + dt
    p.y   = p.y + p.vy * dt
    if p.age >= p.duration then
      table.remove(self.particles, i)
    else
      i = i + 1
    end
  end
end

function DeltaAnim:draw(font)
  if not font then return end
  love.graphics.setFont(font)
  for _, p in ipairs(self.particles) do
    local t     = p.age / p.duration
    local alpha = t < 0.3 and (t/0.3) or (1 - (t-0.3)/0.7)
    alpha = math.max(0, math.min(1, alpha))

    local col = p.value > 0
                and BalanceCfg.choice_hint.colors.positive
                or  BalanceCfg.choice_hint.colors.negative
    love.graphics.setColor(col[1], col[2], col[3], alpha)

    local sign = p.value > 0 and "+" or ""
    local txt  = sign .. tostring(math.floor(p.value + 0.5))
    love.graphics.print(txt, p.x, p.y)
  end
  love.graphics.setColor(1,1,1,1)
end

-- ─── State ────────────────────────────────────────────────────────────

function ActState.new()
  return setmetatable({}, ActState)
end

function ActState:enter(data)
  self.engine      = data.engine
  self.act_id      = data.act_id
  self.act_type    = data.act_type
  self.chapter_ref = data.chapter

  self.engine:startAct(self.act_id)

  self.fade         = 1
  self.timer        = 0
  self.node         = nil
  self.text_shown   = ""
  self.text_full    = ""
  self.text_done    = false
  self.type_timer   = 0
  self.type_index   = 0
  self.type_sfx_counter = 0
  self.hover_choice = nil
  self.buttons      = {}

  -- HUD bar animasyonu (lerp)
  self._hud_display = {}
  local st = self.engine:getState()
  for k in pairs(BalanceEngine.resource_names) do
    self._hud_display[k] = st[k] or 0
  end

  -- Delta animasyonları
  self._deltas = DeltaAnim.new()

  -- Seçim hint önbelleği
  self._choice_hints = {}

  -- HUD alan koordinatları (draw'da hesaplanır, spawnDelta için)
  self._hud_rects = {}

  self.font_speak  = love.graphics.newFont(14)
  self.font_text   = love.graphics.newFont(17)
  self.font_choice = love.graphics.newFont(15)
  self.font_hud    = love.graphics.newFont(12)
  self.font_hint   = love.graphics.newFont(10)
  self.font_delta  = love.graphics.newFont(13)
  self.font_mono   = love.graphics.newFont(10)

  local weights = { life=0.65, rupture=0.20, migration=0.40, outcome=0.50 }
  AudioManager.setMoralWeight(weights[self.act_type] or 0.5)
  if self.act_type == "rupture" then
    AudioManager.playSFX("tension", 0.7)
  end

  self:_loadCurrentNode()
end

function ActState:_loadCurrentNode()
  if self.engine:isActDone() then self:_finishAct(); return end
  self.node = self.engine:current()
  if not self.node then self:_finishAct(); return end

  if self.node.type == "network_reveal" and self.node.network then
    local net     = self.node.network
    local caption = self.node.text
    self.engine:advance()
    StateManager.push("network_reveal", {
      region_id       = net.region or self.engine.chapter_id,
      level           = net.level  or 0,
      highlight_nodes = net.highlight_nodes or {},
      highlight_edges = net.highlight_edges or {},
      caption_text    = caption,
    })
    return
  end

  self.text_full        = self.node.text or ""
  self.text_shown       = ""
  self.text_done        = false
  self.type_timer       = 0
  self.type_index       = 0
  self.type_sfx_counter = 0
  self.buttons          = {}
  self.hover_choice     = nil
  self._choice_hints    = {}
  AudioManager.playSFX("page_flip", 0.55)
end

function ActState:_spawnDeltas(deltas)
  local st = self.engine:getState()
  for key, delta in pairs(deltas) do
    if self._hud_rects[key] then
      local r = self._hud_rects[key]
      self._deltas:spawn(key, delta, r.x + r.w - 12, r.y - 4)
    end
  end
  -- Lerp hedefini güncelle
  for k in pairs(BalanceEngine.resource_names) do
    self._hud_display[k] = self._hud_display[k]  -- lerp var
  end
end

-- ─── Update ──────────────────────────────────────────────────────────

function ActState:update(dt)
  self.timer = self.timer + dt
  if self.fade > 0 then self.fade = math.max(0, self.fade - dt*2) end

  -- HUD bar lerp
  local st   = self.engine:getState()
  local lerp = BalanceCfg.hud.bar_lerp_speed * dt
  for k in pairs(self._hud_display) do
    if st[k] then
      self._hud_display[k] = self._hud_display[k] +
        (st[k] - self._hud_display[k]) * math.min(1, lerp)
    end
  end

  -- Delta animasyonları
  self._deltas:update(dt)

  -- Typewriter (Lua 5.1 uyumlu UTF-8 güvenli)
  if not self.text_done then
    self.type_timer = self.type_timer + dt

    local char_count = utf8_len(self.text_full)
    local new_char   = math.min(math.floor(self.type_timer * TYPEWRITER_SPEED), char_count)

    if new_char > self.type_index then
      self.type_sfx_counter = self.type_sfx_counter + (new_char - self.type_index)
      while self.type_sfx_counter >= TYPEWRITER_SFX_EVERY do
        AudioManager.playSFX("typewriter", 0.32)
        self.type_sfx_counter = self.type_sfx_counter - TYPEWRITER_SFX_EVERY
      end
    end

    self.type_index = new_char

    if new_char >= char_count then
      self.text_shown = self.text_full
      self.text_done  = true
    else
      self.text_shown = utf8_sub(self.text_full, new_char)
    end
  end

  -- Hover
  if self.text_done and self.node and #self.node.choices > 0 then
    local mx, my = Config.toLogical(love.mouse.getPosition())
    local prev   = self.hover_choice
    self.hover_choice = nil
    for i, btn in ipairs(self.buttons) do
      if mx>=btn.x and mx<=btn.x+btn.w and my>=btn.y and my<=btn.y+btn.h then
        self.hover_choice = i; break
      end
    end
    if self.hover_choice ~= prev and self.hover_choice ~= nil then
      AudioManager.playSFX("map_hover", 0.38)
    end
  end
end

-- ─── Draw ────────────────────────────────────────────────────────────

function ActState:draw()
  local W, H = Config.vw(), Config.vh()

  local bg = self:_bgColor()
  love.graphics.setColor(bg[1], bg[2], bg[3], 1)
  love.graphics.rectangle("fill", 0, 0, W, H)

  self:_drawActLabel(W)

  if not self.node then
    if self.fade > 0 then
      love.graphics.setColor(0,0,0,self.fade)
      love.graphics.rectangle("fill", 0,0,W,H)
    end
    return
  end

  self:_drawHUD(W)
  self._deltas:draw(self.font_delta)

  local box_h = 200
  local box_y = H - box_h - 20
  self:_drawDialogBox(20, box_y, W-40, box_h)

  if self.text_done and #self.node.choices > 0 then
    self:_drawChoices(W, box_y)
  elseif self.text_done then
    self:_drawContinueHint(W, H)
  end

  if self.fade > 0 then
    love.graphics.setColor(0,0,0,self.fade)
    love.graphics.rectangle("fill", 0,0,W,H)
  end
  love.graphics.setColor(1,1,1,1)
end

function ActState:_bgColor()
  local t = { life={0.08,0.07,0.05}, rupture={0.10,0.05,0.04},
              migration={0.05,0.06,0.09}, outcome={0.06,0.06,0.06} }
  return t[self.act_type] or {0.07,0.06,0.05}
end

function ActState:_drawActLabel(W)
  local labels = { life="YAŞAM", rupture="KIRILMA", migration="HİCRET", outcome="SONUÇ" }
  love.graphics.setFont(self.font_mono)
  love.graphics.setColor(0.35, 0.32, 0.26, 0.5)
  love.graphics.print("// " .. (labels[self.act_type] or ""), 20, 16)
end

function ActState:_drawHUD(W)
  local st    = self._hud_display
  local crits = BalanceEngine.getCriticals(self.engine:getState())
  local pad   = 20
  local y     = 14

  love.graphics.setFont(self.font_hud)

  local res_order = { "trust", "food", "money", "morale" }
  local item_w    = (W - pad*2) / #res_order

  for i, key in ipairs(res_order) do
    local val   = st[key] or 0
    local col   = BalanceEngine.resource_colors[key]
    local label = BalanceEngine.resource_names[key]
    local x     = pad + (i-1)*item_w
    local is_crit = crits[key]

    -- Kritik: kırmızı yanıp sönme
    local cr, cg, cb = col[1], col[2], col[3]
    if is_crit then
      local pulse = (math.sin(self.timer * BalanceCfg.hud.critical_pulse_rate) + 1) / 2
      cr = cr + pulse * (0.9 - cr)
      cg = cg * (1 - pulse * 0.7)
      cb = cb * (1 - pulse * 0.7)
    end

    -- Etiket
    love.graphics.setColor(is_crit and {0.85,0.30,0.22} or {0.38,0.36,0.30})
    if is_crit then
      love.graphics.setColor(0.85, 0.30, 0.22, 1)
    else
      love.graphics.setColor(0.38, 0.36, 0.30, 1)
    end
    love.graphics.print(label, x, y)

    -- Bar
    local bw, bh = item_w - 22, 3
    love.graphics.setColor(0.16, 0.15, 0.12, 1)
    love.graphics.rectangle("fill", x, y+16, bw, bh)

    local fill = math.max(0, math.min(1, val/100))
    love.graphics.setColor(cr, cg, cb, is_crit and 0.9 or 0.85)
    love.graphics.rectangle("fill", x, y+16, bw*fill, bh)

    -- Değer
    love.graphics.setColor(is_crit and {0.85,0.35,0.25} or {0.55,0.52,0.44})
    if is_crit then
      love.graphics.setColor(0.85, 0.35, 0.25, 1)
    else
      love.graphics.setColor(0.55, 0.52, 0.44, 1)
    end
    love.graphics.print(tostring(math.floor(val+0.5)), x+bw+3, y)

    -- HUD rect kaydı (delta spawn için)
    self._hud_rects[key] = { x=x, y=y, w=bw, h=bh+16 }
  end
end

function ActState:_drawDialogBox(x, y, w, h)
  love.graphics.setColor(0.04, 0.03, 0.03, 0.93)
  love.graphics.rectangle("fill", x, y, w, h, 6)
  love.graphics.setColor(0.22, 0.20, 0.16, 0.55)
  love.graphics.setLineWidth(0.5)
  love.graphics.rectangle("line", x, y, w, h, 6)

  if self.node.speaker then
    love.graphics.setFont(self.font_speak)
    love.graphics.setColor(0.72, 0.65, 0.48, 1)
    love.graphics.print(self.node.speaker, x+16, y+12)
  end

  love.graphics.setFont(self.font_text)
  love.graphics.setColor(0.86, 0.82, 0.74, 1)
  love.graphics.printf(self.text_shown, x+16, y+36, w-32, "left")
  love.graphics.setLineWidth(1)
end

function ActState:_drawChoices(W, box_y)
  self.buttons = {}
  local choices = self.node.choices
  local bw = W - 40
  local bh = 44
  local gap = 8
  local start_y = box_y - (#choices*(bh+gap) - gap) - 14

  love.graphics.setFont(self.font_choice)

  for i, ch in ipairs(choices) do
    local bx = 20
    local by = start_y + (i-1)*(bh+gap)
    table.insert(self.buttons, {x=bx, y=by, w=bw, h=bh, index=i})

    local is_hover = self.hover_choice == i
    love.graphics.setColor(0.75, 0.65, 0.45, is_hover and 0.20 or 0.10)
    love.graphics.rectangle("fill", bx, by, bw, bh, 5)
    love.graphics.setColor(0.75, 0.65, 0.45, is_hover and 0.65 or 0.22)
    love.graphics.setLineWidth(0.5)
    love.graphics.rectangle("line", bx, by, bw, bh, 5)

    -- Numara
    love.graphics.setColor(0.50, 0.46, 0.36, 0.8)
    love.graphics.print(i .. ".", bx+12, by+bh/2-8)

    -- Metin
    local col = is_hover and {0.95,0.90,0.78} or {0.78,0.74,0.62}
    love.graphics.setColor(col[1], col[2], col[3], 1)
    love.graphics.printf(ch.text, bx+32, by+bh/2-8, bw-44-60, "left")

    -- Seçim ipucu (hover'da efekt sembolleri)
    if is_hover and ch.effects then
      local hints = BalanceEngine.getChoiceHints(ch.effects)
      local hx    = bx + bw - 58
      love.graphics.setFont(self.font_hint)
      for j, hint in ipairs(hints) do
        love.graphics.setColor(hint.color[1], hint.color[2], hint.color[3], 0.85)
        love.graphics.print(hint.symbol, hx + (j-1)*18, by + bh/2 - 6)
      end
      love.graphics.setFont(self.font_choice)
    end
  end
  love.graphics.setLineWidth(1)
end

function ActState:_drawContinueHint(W, H)
  local alpha = (math.sin(self.timer*3)+1)/2 * 0.55 + 0.20
  love.graphics.setColor(0.55, 0.50, 0.40, alpha)
  love.graphics.setFont(self.font_hud)
  local hint = "[ Devam için dokun / tıkla ]"
  local tw   = self.font_hud:getWidth(hint)
  love.graphics.print(hint, W/2-tw/2, H-34)
end

-- ─── Girdi ────────────────────────────────────────────────────────────

function ActState:_handleTap(x, y)
  if not self.text_done then
    self.text_shown = self.text_full
    self.text_done  = true
    self.type_index = utf8_len(self.text_full)
    return
  end

  if self.node and #self.node.choices > 0 then
    for _, btn in ipairs(self.buttons) do
      if x>=btn.x and x<=btn.x+btn.w and y>=btn.y and y<=btn.y+btn.h then
        self:_makeChoice(btn.index)
        return
      end
    end
    return
  end

  self.engine:advance()
  -- Drain deltalarını canlandır
  local drain = self.engine:getDrainDeltas()
  if next(drain) then self:_spawnDeltas(drain) end
  self:_loadCurrentNode()
end

function ActState:_makeChoice(i)
  local choices = self.node.choices
  if not choices or not choices[i] then return end

  local effects = choices[i].effects or {}
  local has_pos = (effects.trust  and effects.trust  > 5) or
                  (effects.morale and effects.morale > 5)
  local has_neg = (effects.trust  and effects.trust  < -3) or
                  (effects.food   and effects.food   < -3)

  if has_pos then      AudioManager.playSFX("positive", 0.65)
  elseif has_neg then  AudioManager.playSFX("tension",  0.45)
  else                 AudioManager.playSFX("page_flip",0.50)
  end

  self.engine:choose(i)

  -- Delta animasyonlarını tetikle
  local deltas = self.engine:getLastDeltas()
  if next(deltas) then self:_spawnDeltas(deltas) end

  self:_loadCurrentNode()
end

function ActState:_spawnDeltas(deltas)
  for key, delta in pairs(deltas) do
    if self._hud_rects[key] then
      local r = self._hud_rects[key]
      self._deltas:spawn(key, delta, r.x + r.w - 12, r.y - 6)
    end
  end
end

function ActState:mousepressed(x, y, btn)
  if btn == 1 then self:_handleTap(x, y) end
end
function ActState:touchpressed(id, x, y, p)
  self:_handleTap(x, y)
end
function ActState:touchmoved(id, x, y, dx, dy, p) end

function ActState:keypressed(key)
  if key == "space" or key == "return" then
    if not self.text_done then
      self.text_shown = self.text_full
      self.text_done  = true
      self.type_index = utf8_len(self.text_full)
    elseif self.node and #self.node.choices == 0 then
      self.engine:advance()
      local drain = self.engine:getDrainDeltas()
      if next(drain) then self:_spawnDeltas(drain) end
      self:_loadCurrentNode()
    end
  elseif key >= "1" and key <= "9" then
    local i = tonumber(key)
    if self.text_done and self.node and self.node.choices and
       #self.node.choices >= i then
      self:_makeChoice(i)
    end
  elseif key == "escape" then
    StateManager.switch("world_map")
  end
end

function ActState:resume(data)
  AudioManager.setRegion(self.engine and self.engine.chapter_id or "map")
  self:_loadCurrentNode()
end

function ActState:_finishAct()
  -- Telemetri: bölüm bitti
  BalanceEngine.endSession(self.engine:getState())
  if self.chapter_ref and self.chapter_ref.onActComplete then
    self.chapter_ref:onActComplete({act_id=self.act_id})
  else
    StateManager.switch("world_map")
  end
end

return ActState
