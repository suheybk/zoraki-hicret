--[[
  SaveSystem — Kayıt / Yükleme
  love.filesystem kullanır (platform bağımsız).
  Web'de localStorage'a fallback (love.js ortamında love.filesystem çalışır).
  
  Veri yapısı:
  {
    version     = 1,
    lang        = "tr",
    unlocked    = { "gaza", "uyghur" },
    completed   = { "gaza" },
    chapter_states = {
      gaza = { trust=55, food=8, ... history=[...] }
    },
    archive     = { "doc_silah_1", "doc_veto_2" },
    settings    = { sfx=0.8, music=0.6 }
  }
--]]

local json       = require("src.utils.json")
local SaveSystem = {}

local SAVE_FILE   = "save.json"
local SAVE_VERSION= 1

local _data = nil  -- belleğe yüklenmiş kayıt

--- Varsayılan kayıt
local function _default()
  return {
    version        = SAVE_VERSION,
    lang           = "tr",
    unlocked       = { "gaza" },   -- İlk bölüm açık başlar
    completed      = {},
    chapter_states = {},
    archive        = {},
    settings       = { sfx = 0.8, music = 0.5 },
  }
end

--- Kaydı yükle (yoksa varsayılan oluştur)
function SaveSystem.load()
  local raw = love.filesystem.read(SAVE_FILE)
  if raw then
    local ok, parsed = pcall(json.decode, raw)
    if ok and parsed and parsed.version == SAVE_VERSION then
      _data = parsed
      return _data
    end
  end
  _data = _default()
  return _data
end

--- Kaydı diske yaz
function SaveSystem.save()
  assert(_data, "Önce SaveSystem.load() çağrılmalı")
  local raw = json.encode(_data)
  love.filesystem.write(SAVE_FILE, raw)
end

--- Belleğe yaz + diske kaydet
function SaveSystem.flush()
  if _data then SaveSystem.save() end
end

--- Aktif kayıt verisini döndür
function SaveSystem.get()
  if not _data then SaveSystem.load() end
  return _data
end

--- Bölüm durumunu kaydet
function SaveSystem.saveChapterState(chapter_id, state)
  local d = SaveSystem.get()
  d.chapter_states[chapter_id] = state
  SaveSystem.save()
end

--- Bölümü tamamlandı olarak işaretle
function SaveSystem.completeChapter(chapter_id)
  local d = SaveSystem.get()
  -- Tekrar ekleme
  for _, v in ipairs(d.completed) do
    if v == chapter_id then return end
  end
  table.insert(d.completed, chapter_id)
  SaveSystem.save()
end

--- Arşiv belgesi ekle
function SaveSystem.unlockArchiveDoc(doc_id)
  local d = SaveSystem.get()
  for _, v in ipairs(d.archive) do
    if v == doc_id then return end
  end
  table.insert(d.archive, doc_id)
  SaveSystem.save()
end

--- Bölüm kilidini aç
function SaveSystem.unlockChapter(chapter_id)
  local d = SaveSystem.get()
  for _, v in ipairs(d.unlocked) do
    if v == chapter_id then return end
  end
  table.insert(d.unlocked, chapter_id)
  SaveSystem.save()
end

--- Bölüm açık mı?
function SaveSystem.isUnlocked(chapter_id)
  local d = SaveSystem.get()
  for _, v in ipairs(d.unlocked) do
    if v == chapter_id then return true end
  end
  return false
end

--- Bölüm tamamlandı mı?
function SaveSystem.isCompleted(chapter_id)
  local d = SaveSystem.get()
  for _, v in ipairs(d.completed) do
    if v == chapter_id then return true end
  end
  return false
end

--- Ayarları güncelle
function SaveSystem.setSetting(key, value)
  local d = SaveSystem.get()
  d.settings[key] = value
  SaveSystem.save()
end

function SaveSystem.getSetting(key, default)
  local d = SaveSystem.get()
  local v = d.settings[key]
  return v ~= nil and v or default
end

--- Kaydı sil (debug / yeni oyun)
function SaveSystem.reset()
  _data = _default()
  SaveSystem.save()
end

return SaveSystem
