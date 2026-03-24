--[[
  NarrativeEngine — JSON Tabanlı Anlatı Motoru
  
  Bölüm dosyası yapısı (data/chapters/{id}.json):
  {
    "id": "gaza",
    "title_key": "chapter.gaza.title",
    "acts": [
      {
        "id": "act_1",
        "type": "life",          -- "life" | "rupture" | "migration" | "outcome"
        "nodes": [
          {
            "id": "node_start",
            "speaker": "narrator",
            "text_key": "gaza.act1.node_start.text",
            "choices": [
              {
                "text_key": "gaza.act1.choice_a",
                "next": "node_2",
                "effects": { "trust": 5, "resource_food": -1 }
              }
            ],
            "next": "node_2"    -- seçim yoksa otomatik geçiş
          }
        ],
        "entry": "node_start"
      }
    ]
  }
  
  Kullanım:
    local eng = NarrativeEngine.new("gaza")
    eng:startAct("act_1")
    local node = eng:current()    → { speaker, text_key, choices, ... }
    eng:choose(1)                 → seçim index ile ilerle
    eng:advance()                 → seçimsiz ilerle
    eng:isActDone()               → bool
--]]

local json      = require("src.utils.json")
local I18n      = require("src.systems.i18n")
local BE        = require("src.systems.balance_engine")

local NarrativeEngine = {}
NarrativeEngine.__index = NarrativeEngine

--- Yeni motor örneği
-- @param chapter_id  string  data/chapters/{id}.json
function NarrativeEngine.new(chapter_id)
  local self = setmetatable({}, NarrativeEngine)

  -- Dosyayı yükle
  local path = "data/chapters/" .. chapter_id .. ".json"
  local raw  = love.filesystem.read(path)
  assert(raw, "Bölüm dosyası bulunamadı: " .. path)
  self.data = json.decode(raw)

  -- Durum
  self.chapter_id   = chapter_id
  self.current_act  = nil
  self.act_data     = nil
  self.node_map     = {}
  self.current_node = nil
  self.done         = false

  -- Oyuncu durumu (kaynak, karar kayıtları)
  self.state = {
    trust    = 50,
    food     = 10,
    money    = 10,
    document = 0,
    morale   = 50,
    history  = {},     -- verilen kararların kaydı
    flags    = {},     -- story flag'leri
  }

  return self
end

--- Belirtilen aksiyonu başlat
function NarrativeEngine:startAct(act_id)
  -- Act'ı bul
  local found = nil
  for _, act in ipairs(self.data.acts) do
    if act.id == act_id then found = act; break end
  end
  assert(found, "Act bulunamadı: " .. act_id)

  self.act_data    = found
  self.current_act = act_id
  self.done        = false

  -- Node haritası oluştur
  self.node_map = {}
  for _, node in ipairs(found.nodes) do
    self.node_map[node.id] = node
  end

  -- Denge motoru: perde başı normalizasyonu + chapter init
  BE.onActStart(self.state, found.type, self.chapter_id)
  if BE.startSession then BE.startSession(self.chapter_id) end

  -- Giriş node'una geç
  self:_gotoNode(found.entry)
end

--- Aktif node'u döndür (çevrilmiş metin ile)
function NarrativeEngine:current()
  if not self.current_node then return nil end
  local node = self.current_node

  -- Metni çevir
  local text = I18n.t(node.text_key or "")
  local speaker_name = I18n.t("speaker." .. (node.speaker or "narrator"))

  -- Seçenekleri çevir
  local choices = {}
  if node.choices then
    for i, ch in ipairs(node.choices) do
      -- Koşullu seçenek görünürlüğü
      local visible = true
      if ch.condition then
        visible = self:_evalCondition(ch.condition)
      end
      if visible then
        table.insert(choices, {
          index   = i,
          text    = I18n.t(ch.text_key or ""),
          effects = ch.effects,
        })
      end
    end
  end

  return {
    id      = node.id,
    speaker = speaker_name,
    text    = text,
    choices = choices,
    type    = node.type or "dialogue",
    media   = node.media,   -- { type="image", path="..." } opsiyonel
    sound   = node.sound,
    network = node.network,   -- network_reveal tipi için { region, level, highlight_nodes, highlight_edges, caption_key }
  }
end

--- Seçim yap (1-tabanlı indeks)
function NarrativeEngine:choose(choice_index)
  if not self.current_node or not self.current_node.choices then return end

  -- Görünür seçenekleri yeniden derle
  local visible = {}
  for _, ch in ipairs(self.current_node.choices) do
    local ok = true
    if ch.condition then ok = self:_evalCondition(ch.condition) end
    if ok then table.insert(visible, ch) end
  end

  local ch = visible[choice_index]
  if not ch then return end

  -- Etkileri uygula (BalanceEngine üzerinden: ölçekli + dayanışma bonusu)
  local ctx = { is_solidarity = ch.solidarity == true }
  self._last_deltas = ch.effects
      and BE.applyEffects(self.state, ch.effects, ctx)
      or {}

  -- Telemetri
  BE.recordChoice(self.current_node.id, choice_index, ch.effects)

  -- Karar geçmişine kaydet
  table.insert(self.state.history, {
    act    = self.current_act,
    node   = self.current_node.id,
    choice = choice_index,
    key    = ch.text_key,
  })

  -- Pasif zaman baskısı
  if self.act_data then
    local drain = BE.onNodeAdvance(self.state, self.act_data.type)
    for k, v in pairs(drain) do
      self._last_deltas[k] = (self._last_deltas[k] or 0) + v
    end
  end

  -- Sonraki node'a git
  if ch.next then
    self:_gotoNode(ch.next)
  else
    self:_endAct()
  end
end

--- Seçimsiz ilerleme
function NarrativeEngine:advance()
  if not self.current_node then return end
  -- Pasif zaman baskısı
  if self.act_data then
    self._drain_deltas = BE.onNodeAdvance(self.state, self.act_data.type)
  end
  local next = self.current_node.next
  if next then
    self:_gotoNode(next)
  else
    self:_endAct()
  end
end

function NarrativeEngine:isActDone()
  return self.done
end

--- Oyuncu durumunu döndür
function NarrativeEngine:getState()
  return self.state
end

--- Story flag'i ayarla / oku
function NarrativeEngine:setFlag(key, value)
  self.state.flags[key] = value
end

function NarrativeEngine:getFlag(key)
  return self.state.flags[key]
end

--- Bölümdeki tüm act ID'lerini döndür
function NarrativeEngine:getActList()
  local list = {}
  for _, act in ipairs(self.data.acts) do
    table.insert(list, { id = act.id, type = act.type })
  end
  return list
end

-- ─── Özel yardımcılar ──────────────────────────────────────────────

function NarrativeEngine:_gotoNode(node_id)
  local node = self.node_map[node_id]
  if not node then
    print("[Narrative] Node bulunamadı: " .. tostring(node_id))
    self:_endAct()
    return
  end
  self.current_node = node

  -- Otomatik efektler (node'a girildiğinde)
  if node.on_enter then
    self:_applyEffects(node.on_enter)
  end
end

function NarrativeEngine:_endAct()
  self.done         = true
  self.current_node = nil
end

function NarrativeEngine:_applyEffects(effects)
  -- Flag işlemleri önce ayrılır
  local numeric = {}
  for key, delta in pairs(effects) do
    if key == "flag" then
      if type(delta) == "table" then
        self.state.flags[delta.key] = delta.value
      end
    elseif type(delta) == "number" then
      numeric[key] = delta
    end
  end
  -- Sayısal etkiler BalanceEngine üzerinden
  if next(numeric) then
    BE.applyEffects(self.state, numeric, {})
  end
end

function NarrativeEngine:_evalCondition(cond)
  -- Basit koşul: { flag="seen_map" } veya { min_trust=30 }
  if cond.flag then
    return self.state.flags[cond.flag] == true
  end
  if cond.min_trust then
    return self.state.trust >= cond.min_trust
  end
  if cond.min_food then
    return self.state.food >= cond.min_food
  end
  return true
end

--- Son seçim delta'larını döndür (HUD animasyonu için)
function NarrativeEngine:getLastDeltas()
  return self._last_deltas or {}
end

--- Son pasif drain delta'larını döndür
function NarrativeEngine:getDrainDeltas()
  return self._drain_deltas or {}
end

return NarrativeEngine
