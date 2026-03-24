--[[
  BalanceEngine — Kaynak Dengesi Motoru
  
  NarrativeEngine'in üstünde oturur.
  Kaynak değişimlerini ölçekler, kritik durumları algılar,
  perde geçişlerini normalleştirir, telemetri kaydeder.
  
  Kullanım (NarrativeEngine içinden):
    local BE = require("src.systems.balance_engine")
    
    -- Kaynak değiştir (ham delta → ölçeklenmiş)
    BE.applyEffects(state, effects, context)
    
    -- Perde geçişinde çağır
    BE.onActStart(state, act_type)
    
    -- Her node geçişinde çağır (pasif drain)
    BE.onNodeAdvance(state, act_type)
    
    -- Kritik durum kontrolü
    local crits = BE.getCriticals(state)
    
    -- Final skor
    local score, label = BE.finalScore(state)
--]]

local B = require("src.systems.balance_config")

local BalanceEngine = {}

-- ─── Efekt Uygulama ──────────────────────────────────────────────────

--- Seçim efektlerini state'e uygula (ölçeklenmiş)
-- @param state      table   engine.state
-- @param effects    table   { trust=5, food=-2, ... }
-- @param context    table   { is_solidarity=bool } opsiyonel
-- @return           table   { key → actual_delta } (HUD için)
function BalanceEngine.applyEffects(state, effects, context)
  if not effects then return {} end
  context = context or {}

  local deltas = {}

  for key, raw_delta in pairs(effects) do
    if type(raw_delta) == "number" and state[key] ~= nil then
      local scale = B.effect_scale[key] or 1.0
      local delta = raw_delta * scale

      -- Dayanışma bonusu (başkasına yardım eden seçimler)
      if context.is_solidarity then
        if key == "trust" and delta > 0 then
          delta = delta * B.solidarity_bonus.trust_mult
        end
      end

      -- Uygula + sınırla
      local lim   = B.limits[key]
      local old   = state[key]
      state[key]  = math.max(lim.min, math.min(lim.max, old + delta))
      deltas[key] = state[key] - old  -- gerçek değişim (yuvarlama sonrası)
    end
  end

  -- Dayanışma moral bonusu
  if context.is_solidarity then
    local lim = B.limits.morale
    local old = state.morale
    state.morale = math.max(lim.min, math.min(lim.max,
      state.morale + B.solidarity_bonus.morale_add))
    deltas.morale = (deltas.morale or 0) + (state.morale - old)
  end

  return deltas
end

--- Pasif zaman baskısı: her node geçişinde uygula
function BalanceEngine.onNodeAdvance(state, act_type)
  local drain = B.act_drain[act_type or "life"] or {}
  local deltas = {}

  for key, d in pairs(drain) do
    if state[key] ~= nil then
      local lim = B.limits[key]
      local old = state[key]
      state[key] = math.max(lim.min, math.min(lim.max, state[key] + d))
      deltas[key] = state[key] - old
    end
  end

  return deltas
end

--- Perde geçişinde kaynakları normalleştir
function BalanceEngine.onActStart(state, act_type, chapter_id)
  -- Önceki perde birikmiş cezayı hafifletmek için taban değer koy
  local tr = B.act_transition

  if state.food < tr.food_floor then
    state.food = tr.food_floor
  end
  if state.morale < tr.morale_floor then
    state.morale = tr.morale_floor
  end

  -- Bölüm başlangıcında chapter_initial uygula (sadece ilk act için)
  if act_type == "life" and chapter_id then
    local ci = B.chapter_initial[chapter_id]
    if ci then
      for k, v in pairs(ci) do
        if state[k] ~= nil then
          state[k] = v
        end
      end
    else
      -- Varsayılan başlangıç
      for k, v in pairs(B.initial) do
        if state[k] ~= nil then
          state[k] = v
        end
      end
    end
  end
end

-- ─── Kritik Durum Algılama ────────────────────────────────────────────

--- Kritik kaynakları döndür
-- @return table { key → true } veya {}
function BalanceEngine.getCriticals(state)
  local crits = {}
  for key, threshold in pairs(B.critical) do
    if state[key] ~= nil and state[key] <= threshold then
      crits[key] = true
    end
  end
  return crits
end

--- Oyun sonu başarısızlık kontrolü
-- @return bool, string (başarısız mı, neden)
function BalanceEngine.checkFailure(state)
  for key, threshold in pairs(B.failure_thresholds) do
    if state[key] ~= nil and state[key] <= threshold then
      return true, key
    end
  end
  return false, nil
end

-- ─── Seçim İpucu ─────────────────────────────────────────────────────

--- Seçim hover göstergesi için sembol+renk
-- @param effects table { trust=5, food=-2, ... }
-- @return table [{ symbol, color, key }]
function BalanceEngine.getChoiceHints(effects)
  if not B.choice_hint.show_on_hover then return {} end
  if not effects then return {} end

  local hints = {}
  local S     = B.choice_hint.symbols
  local C     = B.choice_hint.colors
  local thresh = B.choice_hint.threshold_show

  -- Önem sırasına göre: morale, food, trust, money
  local order = { "morale", "food", "trust", "money", "document" }

  for _, key in ipairs(order) do
    local raw = effects[key]
    if raw and math.abs(raw) >= thresh then
      local scaled = raw * (B.effect_scale[key] or 1.0)
      local sym, col

      if scaled >= 8 then
        sym, col = S.big_up,   C.positive
      elseif scaled >= thresh then
        sym, col = S.small_up, C.positive
      elseif scaled <= -8 then
        sym, col = S.big_dn,   C.negative
      elseif scaled <= -thresh then
        sym, col = S.small_dn, C.negative
      else
        sym, col = S.neutral,  C.neutral
      end

      table.insert(hints, {
        key    = key,
        symbol = sym,
        color  = col,
        value  = math.floor(scaled),
      })
    end
  end

  return hints
end

-- ─── Final Skor ──────────────────────────────────────────────────────

--- Oyun sonu ağırlıklı skor ve label
-- @return number (0–100), string label
function BalanceEngine.finalScore(state)
  local score = 0
  local w     = B.outcome_weights

  for key, weight in pairs(w) do
    local lim = B.limits[key] or { min=0, max=100 }
    local norm = (state[key] - lim.min) / math.max(1, lim.max - lim.min)
    score = score + norm * weight * 100
  end
  score = math.floor(score + 0.5)

  local t  = B.outcome_thresholds
  local lbl
  if score >= t.excellent then
    lbl = "ayakta"
  elseif score >= t.good then
    lbl = "bedel_odendi"
  elseif score >= t.hard then
    lbl = "kirilmak_uzere"
  else
    lbl = "degisti"
  end

  return score, lbl
end

-- ─── Telemetri ───────────────────────────────────────────────────────

local _telemetry = {
  sessions = {},
  current  = nil,
}

function BalanceEngine.startSession(chapter_id)
  if not B.telemetry.enabled then return end
  _telemetry.current = {
    chapter  = chapter_id,
    started  = os.time(),
    snapshots= {},    -- { act, node_idx, state_copy }
    choices  = {},    -- { node_id, choice_idx, effects }
  }
end

function BalanceEngine.recordSnapshot(act_id, node_idx, state)
  if not B.telemetry.enabled or not _telemetry.current then return end
  local snap = { act=act_id, n=node_idx }
  for _, k in ipairs(B.telemetry.track_fields) do
    snap[k] = state[k]
  end
  table.insert(_telemetry.current.snapshots, snap)
end

function BalanceEngine.recordChoice(node_id, choice_idx, effects)
  if not B.telemetry.enabled or not _telemetry.current then return end
  table.insert(_telemetry.current.choices, {
    node   = node_id,
    choice = choice_idx,
    fx     = effects,
  })
end

function BalanceEngine.endSession(final_state)
  if not B.telemetry.enabled or not _telemetry.current then return end
  local sess = _telemetry.current
  sess.ended = os.time()
  sess.duration = sess.ended - sess.started
  local score, lbl = BalanceEngine.finalScore(final_state)
  sess.final_score = score
  sess.outcome_label = lbl
  for _, k in ipairs(B.telemetry.track_fields) do
    sess["final_" .. k] = final_state[k]
  end
  table.insert(_telemetry.sessions, sess)

  -- Diske yaz
  local json = require("src.utils.json")
  local ok, raw = pcall(json.encode, _telemetry.sessions)
  if ok then
    pcall(love.filesystem.write, B.telemetry.save_path, raw)
  end

  _telemetry.current = nil
end

--- Tüm telemetri verisini döndür (debug ekranı için)
function BalanceEngine.getTelemetry()
  return _telemetry
end

-- ─── Kaynak İsimleri (UI için) ────────────────────────────────────────

BalanceEngine.resource_names = {
  trust    = "Güven",
  food     = "Yiyecek",
  money    = "Para",
  morale   = "Moral",
  document = "Belge",
}

BalanceEngine.resource_colors = {
  trust    = { 0.40, 0.75, 0.55 },
  food     = { 0.85, 0.65, 0.30 },
  money    = { 0.60, 0.60, 0.85 },
  morale   = { 0.75, 0.40, 0.55 },
  document = { 0.85, 0.78, 0.45 },
}

return BalanceEngine
