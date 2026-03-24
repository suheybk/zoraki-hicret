--[[
  OutcomeState — Bölüm Sonuç Ekranı
  Oyuncu kararlarının özetini ve "Zulüm Ağı" ifşasını gösterir.
--]]

local StateManager  = require("src.systems.state_manager")
local BalanceEngine = require("src.systems.balance_engine")
local BalanceCfg    = require("src.systems.balance_config")
local AudioManager = require("src.systems.audio_manager")
local SaveSystem   = require("src.systems.save_system")
local I18n         = require("src.systems.i18n")
local Config       = require("src.utils.config")

local OutcomeState = {}
OutcomeState.__index = OutcomeState

function OutcomeState.new()
  return setmetatable({}, OutcomeState)
end

function OutcomeState:enter(data)
  self.chapter_id = data.chapter_id
  self.state      = data.state or {}
  self.fade       = 1
  self.timer      = 0
  self.phase      = "reveal"  -- "reveal" | "network" | "action"
  self.scroll     = 0

  self.font_title = love.graphics.newFont(28)
  self.font_body  = love.graphics.newFont(16)
  self.font_small = love.graphics.newFont(13)
  self.font_mono  = love.graphics.newFont(12)

  -- Arşiv belgelerini aç (bu bölüme ait)
  -- Bölüm tamamlanma sesi
  AudioManager.playSFX("chapter_done", 0.75)
  -- Harita ambiyansına geri dön
  AudioManager.setRegion("map")

  -- Final skor hesapla
  self._score, self._outcome_label = BalanceEngine.finalScore(self.state)

  local docs = self:_getChapterDocs()
  for _, doc_id in ipairs(docs) do
    SaveSystem.unlockArchiveDoc(doc_id)
  end
end

function OutcomeState:update(dt)
  self.timer = self.timer + dt
  if self.fade > 0 then
    self.fade = math.max(0, self.fade - dt * 1.5)
  end
end

function OutcomeState:draw()
  local W, H = Config.vw(), Config.vh()

  love.graphics.setColor(0.05, 0.05, 0.04, 1)
  love.graphics.rectangle("fill", 0, 0, W, H)

  -- Başlık
  love.graphics.setFont(self.font_title)
  love.graphics.setColor(0.85, 0.80, 0.65, 1)
  local title_key = "region." .. (self.chapter_id or "?") .. ".name"
  local title = I18n.t(title_key)
  if title:sub(1,1) == "[" then title = self.chapter_id or "?" end
  love.graphics.print(title .. " — Sonuç", 40, 36)

  -- Yatay çizgi
  love.graphics.setColor(0.30, 0.27, 0.22, 0.5)
  love.graphics.setLineWidth(0.5)
  love.graphics.line(40, 72, W - 40, 72)

  -- Kaynak özeti
  self:_drawResourceSummary(40, 88, W - 80)

  -- İfşa notu
  love.graphics.setFont(self.font_body)
  love.graphics.setColor(0.70, 0.65, 0.52, 1)
  local note_key = "outcome." .. (self.chapter_id or "generic") .. ".note"
  local note = I18n.t(note_key)
  if note:sub(1,1) == "[" then
    note = "Bu bölümde yaşananlar gerçek olaylardan ilham almıştır.\nBelge arşivine geçerek daha fazlasını öğren."
  end
  love.graphics.printf(note, 40, 240, W - 80, "left")

  -- Butonlar
  self:_drawButtons(W, H)

  -- Fade
  if self.fade > 0 then
    love.graphics.setColor(0, 0, 0, self.fade)
    love.graphics.rectangle("fill", 0, 0, W, H)
  end

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setLineWidth(1)
end

function OutcomeState:_drawResourceSummary(x, y, w)
  local st = self.state
  love.graphics.setFont(self.font_small)

  local items = {
    { key="trust",  label="Güven"    },
    { key="food",   label="Yiyecek"  },
    { key="money",  label="Para"     },
    { key="morale", label="Moral"    },
  }

  local col_w = w / #items
  for i, item in ipairs(items) do
    local ix  = x + (i-1)*col_w
    local val = st[item.key] or 0
    local col = BalanceEngine.resource_colors[item.key] or {0.6,0.6,0.6}

    love.graphics.setColor(0.40, 0.38, 0.32, 1)
    love.graphics.print(item.label, ix, y)

    -- Mini bar
    local bw, bh = col_w - 16, 3
    love.graphics.setColor(0.16, 0.15, 0.12, 1)
    love.graphics.rectangle("fill", ix, y+36, bw, bh)
    local fill = math.max(0, math.min(1, val/100))
    love.graphics.setColor(col[1], col[2], col[3], 0.85)
    love.graphics.rectangle("fill", ix, y+36, bw*fill, bh)

    love.graphics.setColor(col[1], col[2], col[3], 1)
    love.graphics.setFont(self.font_title)
    love.graphics.print(tostring(math.floor(val+0.5)), ix, y+14)
    love.graphics.setFont(self.font_small)
  end

  -- Final skor
  if self._score then
    local score_labels = {
      ayakta         = "Hayatta kaldın ve ayakta kaldın.",
      bedel_odendi   = "Ağır bedeller ödeyerek geçtin.",
      kirilmak_uzere = "Neredeyse kırıldın.",
      degisti        = "Bu yolculuk seni değiştirdi.",
    }
    local slabel = score_labels[self._outcome_label] or ""
    love.graphics.setColor(0.65, 0.60, 0.46, 0.85)
    love.graphics.print(slabel, x, y + 50)

    -- Skor bar
    love.graphics.setColor(0.20, 0.18, 0.14, 1)
    love.graphics.rectangle("fill", x, y+68, w, 2)
    local sc_fill = math.max(0, math.min(1, (self._score or 0)/100))
    local sc_col = sc_fill > 0.7 and {0.45,0.82,0.55}
                or sc_fill > 0.5 and {0.82,0.75,0.40}
                or sc_fill > 0.3 and {0.82,0.60,0.25}
                or                   {0.82,0.35,0.25}
    love.graphics.setColor(sc_col[1], sc_col[2], sc_col[3], 0.8)
    love.graphics.rectangle("fill", x, y+68, w*sc_fill, 2)

    love.graphics.setFont(self.font_body)
    love.graphics.setColor(0.50, 0.47, 0.37, 0.8)
    love.graphics.print("Yolculuk puanı: " .. tostring(self._score or 0) .. "/100", x, y+76)
  end
end

function OutcomeState:_drawButtons(W, H)
  love.graphics.setFont(self.font_body)
  local btns = {
    { label = "Zulüm Ağını Gör",  action = "network" },
    { label = "Arşive Git",       action = "archive" },
    { label = "Haritaya Dön",     action = "map"     },
    { label = "Ana Menüye Dön",   action = "menu"    },
  }

  local bw, bh = 180, 42
  local gap     = 16
  local total   = #btns * (bw + gap) - gap
  local sx      = W/2 - total/2
  local by      = H - 80

  self._btns = {}
  for i, b in ipairs(btns) do
    local bx = sx + (i-1)*(bw+gap)
    table.insert(self._btns, { x=bx, y=by, w=bw, h=bh, action=b.action })

    love.graphics.setColor(0.18, 0.16, 0.13, 0.9)
    love.graphics.rectangle("fill", bx, by, bw, bh, 6)
    love.graphics.setColor(0.50, 0.45, 0.35, 0.7)
    love.graphics.setLineWidth(0.5)
    love.graphics.rectangle("line", bx, by, bw, bh, 6)
    love.graphics.setColor(0.80, 0.75, 0.60, 1)
    local tw = self.font_body:getWidth(b.label)
    love.graphics.print(b.label, bx + bw/2 - tw/2, by + bh/2 - 8)
  end
  love.graphics.setLineWidth(1)
end

function OutcomeState:_handleTap(x, y)
  if not self._btns then return end
  for _, btn in ipairs(self._btns) do
    if x >= btn.x and x <= btn.x+btn.w and y >= btn.y and y <= btn.y+btn.h then
      if btn.action == "network" then
        StateManager.push("network", {
          region_id = self.chapter_id,
          level     = 3,   -- bölüm tamamlandığında tüm ağ açık
        })
      elseif btn.action == "archive" then
        StateManager.switch("archive")
      elseif btn.action == "map" then
        StateManager.switch("world_map")
      elseif btn.action == "menu" then
        StateManager.switch("menu")
      end
      return
    end
  end
end

function OutcomeState:_getChapterDocs()
  -- Her bölüm için örnek belge kilit açma listesi
  local docs = {
    gaza    = { "doc_silah_gazze", "doc_veto_abd", "doc_abluka" },
    uyghur  = { "doc_gozetim_cin", "doc_kamp_uyghur" },
    rohingya= { "doc_vatansiz_rohingya", "doc_tekne_yolculugu" },
    uyghur  = { "doc_ijop_sistemi", "doc_zorla_calisma", "doc_kamp_uyghur" },
    rohingya= { "doc_myanmar_1982", "doc_icj_myanmar", "doc_vatansiz_rohingya" },
    syria   = { "doc_aleppo_barrel", "doc_alan_kurdi", "doc_veto_rusya" },
    yemen   = { "doc_hodeidah_blockade", "doc_yemen_arms" },
    kashmir = { "doc_kashmir_psa", "doc_internet_blackout" },
  }
  return docs[self.chapter_id] or {}
end

function OutcomeState:mousepressed(x, y, btn)
  if btn == 1 then self:_handleTap(x, y) end
end
function OutcomeState:touchpressed(id, x, y, p)
  self:_handleTap(x, y)
end
function OutcomeState:keypressed(key)
  if key=="s" or key=="," then StateManager.push("settings") end
  if key == "escape" then StateManager.switch("menu") end
end

return OutcomeState
