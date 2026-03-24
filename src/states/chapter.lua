--[[
  ChapterState — Bölüm Yöneticisi
  JSON bölüm verisini yükler, act sırasını yönetir,
  ActState'e geçişleri koordine eder.
--]]

local StateManager     = require("src.systems.state_manager")
local NarrativeEngine  = require("src.systems.narrative_engine")
local SaveSystem       = require("src.systems.save_system")
local I18n             = require("src.systems.i18n")
local AudioManager     = require("src.systems.audio_manager")
local Config           = require("src.utils.config")

local ChapterState = {}
ChapterState.__index = ChapterState

function ChapterState.new()
  return setmetatable({}, ChapterState)
end

function ChapterState:enter(data)
  self.chapter_id = data.chapter_id
  assert(self.chapter_id, "chapter_id gerekli")

  -- Anlatı motorunu başlat
  local ok, engine = pcall(NarrativeEngine.new, self.chapter_id)
  if not ok then
    print("[Chapter] Motor başlatılamadı: " .. tostring(engine))
    StateManager.switch("world_map")
    return
  end
  self.engine   = engine
  self.act_list = engine:getActList()
  self.act_index= 0

  -- Kaydedilmiş ilerleme varsa uygula
  local saved = SaveSystem.get().chapter_states[self.chapter_id]
  if saved then
    engine.state = saved
    -- Son tamamlanan act'tan devam
    self.act_index = saved._act_index or 0
  end

  -- Bölge ambiyansını başlat
  AudioManager.setRegion(self.chapter_id)

  -- Giriş ekranı
  self.phase     = "intro"   -- "intro" | "acting" | "outro"
  self.fade      = 1
  self.timer     = 0
  self.intro_dur = 3.0       -- intro süresi (sn)

  self.font_title  = love.graphics.newFont(36)
  self.font_region = love.graphics.newFont(16)

  local title_key = "region." .. self.chapter_id .. ".name"
  self.title_text = I18n.t(title_key)
  if self.title_text:sub(1,1) == "[" then
    self.title_text = self.chapter_id
  end
end

function ChapterState:update(dt)
  self.timer = self.timer + dt

  if self.fade > 0 then
    self.fade = math.max(0, self.fade - dt * 2)
  end

  if self.phase == "intro" then
    if self.timer >= self.intro_dur then
      self:_startNextAct()
    end

  elseif self.phase == "acting" then
    -- Act tamamlandıysa sıradakine geç
    -- (ActState tamamlandığında bu state'e mesaj gönderir)
    -- Bu ChapterState.onActComplete() üzerinden gelir

  end
end

function ChapterState:draw()
  local W, H = Config.vw(), Config.vh()

  if self.phase == "intro" then
    love.graphics.setColor(0.06, 0.05, 0.04, 1)
    love.graphics.rectangle("fill", 0, 0, W, H)

    -- Yatay çizgi aksanı
    love.graphics.setColor(0.75, 0.65, 0.45, 0.4)
    love.graphics.setLineWidth(0.5)
    love.graphics.line(80, H/2 - 50, W - 80, H/2 - 50)

    -- Başlık
    love.graphics.setFont(self.font_title)
    love.graphics.setColor(0.88, 0.83, 0.70, 1)
    local tw = self.font_title:getWidth(self.title_text)
    love.graphics.print(self.title_text, W/2 - tw/2, H/2 - 35)

    -- Alttaki ince açıklama
    love.graphics.setFont(self.font_region)
    love.graphics.setColor(0.45, 0.43, 0.36, 1)
    local sub = I18n.t("chapter.enter_prompt")
    if sub:sub(1,1) == "[" then sub = "Yükleniyor..." end
    local sw = self.font_region:getWidth(sub)
    love.graphics.print(sub, W/2 - sw/2, H/2 + 20)

    love.graphics.setLineWidth(1)
  end

  -- Fade
  if self.fade > 0 then
    love.graphics.setColor(0, 0, 0, self.fade)
    love.graphics.rectangle("fill", 0, 0, W, H)
  end

  love.graphics.setColor(1, 1, 1, 1)
end

--- Act tamamlandığında ActState'ten çağrılır
function ChapterState:onActComplete(result)
  -- result: { act_id, outcome, state }
  if self.act_index >= #self.act_list then
    -- Tüm act'lar bitti — doğrudan sonuç ekranına geç
    SaveSystem.completeChapter(self.chapter_id)

    local chapter_order = { "gaza", "uyghur", "rohingya", "syria", "yemen", "kashmir" }
    for i, ch in ipairs(chapter_order) do
      if ch == self.chapter_id and chapter_order[i + 1] then
        SaveSystem.unlockChapter(chapter_order[i + 1])
        break
      end
    end

    local state = self.engine:getState()
    state._act_index = self.act_index
    SaveSystem.saveChapterState(self.chapter_id, state)
    StateManager.switch("outcome", {
      chapter_id = self.chapter_id,
      state      = self.engine:getState(),
    })
  else
    self:_startNextAct()
  end
end

function ChapterState:_startNextAct()
  self.act_index = self.act_index + 1
  if self.act_index > #self.act_list then
    -- Güvenlik: bu duruma düşmemeli ama düşerse sonuç ekranına git
    self:onActComplete({})
    return
  end
  local act_info = self.act_list[self.act_index]
  self.phase     = "acting"
  StateManager.switch("act", {
    engine   = self.engine,
    act_id   = act_info.id,
    act_type = act_info.type,
    chapter  = self,   -- geri bildirim için referans
  })
end

function ChapterState:keypressed(key)
  if key == "escape" then
    -- Dünya haritasına dön (kayıt yap)
    local state = self.engine:getState()
    state._act_index = self.act_index
    SaveSystem.saveChapterState(self.chapter_id, state)
    StateManager.switch("world_map")
  end
end

return ChapterState
