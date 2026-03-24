--[[
  ArchiveState — Tanıklık Arşivi
  Kilit açılmış belgeleri listeler.
  Her belge gerçek kaynaklara atıf içerir.
--]]

local StateManager = require("src.systems.state_manager")
local SaveSystem   = require("src.systems.save_system")
local I18n         = require("src.systems.i18n")
local Config       = require("src.utils.config")

local ArchiveState = {}
ArchiveState.__index = ArchiveState

-- Belge meta veri (gerçek oyunda data/archive.json'dan okunur)
local DOC_META = {
  doc_hodeidah_blockade = {
    title = "Hudeyda Limanı Ablukası",
    type  = "İnsani Hukuk",
    color = { 0.83, 0.35, 0.52 },
    body  = "Hudeyda Limanı Yemen'in gıda ithalatının %70'ini karşılıyor. Suudi koalisyonunun 2015'ten bu yana uyguladığı abluka ve kısıtlamalar milyonlarca insanı gıda güvensizliğine sürükledi. BM bu uygulamayı uluslararası insancıl hukuk ihlali olarak nitelendirdi.\n\nKaynak: OCHA Yemen Raporları, WFP Veri Tabanı 2022.",
  },
  doc_yemen_arms = {
    title = "Yemen'e Silah Satışları",
    type  = "Silah Ticareti",
    color = { 0.83, 0.35, 0.52 },
    body  = "ABD 2015-2021 arasında Suudi Arabistan'a 64.1 milyar dolarlık silah sattı. İngiltere aynı dönemde 23 milyar sterlinlik lisans onayladı. Her iki ülkenin silahları Yemenli sivil altyapısını hedef alan saldırılarda kullanıldı.\n\nKaynak: SIPRI, Amnesty International Arms Report 2022.",
  },
  doc_kashmir_psa = {
    title = "Keşmir: Kamu Düzeni Yasası",
    type  = "Hukuki Belge",
    color = { 0.55, 0.50, 0.92 },
    body  = "1978'de çıkarılan PSA (Public Safety Act), suçlama ve yargı olmadan iki yıla kadar gözaltına olanak tanıyor. Keşmir'de 2019-2023 arasında 2.300'den fazla kişiye uygulandı. Uluslararası Af Örgütü bu yasayı 'adaletsiz gözaltı aracı' olarak tanımladı.\n\nKaynak: Amnesty International, J&K High Court Records.",
  },
  doc_internet_blackout = {
    title = "213 Gün: Dünyanın En Uzun Ablukası",
    type  = "Teknoloji & İnsan Hakları",
    color = { 0.55, 0.50, 0.92 },
    body  = "Ağustos 2019'dan Mart 2020'ye kadar Keşmir'de 4G internet hizmetleri tamamen kesildi. Bu, bir demokrasi tarafından uygulanan en uzun internet kesintisi olarak kayıtlara geçti. 7 milyon kişi haberden, sağlık bilgisinden ve ekonomik faaliyetten yoksun kaldı.\n\nKaynak: Access Now, Software Freedom Law Centre India.",
  },
  doc_myanmar_1982 = {
    title = "Myanmar 1982 Vatandaşlık Kanunu",
    type  = "Hukuki Belge",
    color = { 0.94, 0.62, 0.15 },
    body  = "Kanun 135 etnik grubu tanıyor, Rohingya bunların arasında yok. Bu yasal dışlama eğitim, sağlık, seyahat ve evlilik haklarını doğrudan etkiliyor. ICJ 2023'te Myanmar'ı soykırım uygulamakla suçladı.\n\nKaynak: ICJ Proceedings, Human Rights Watch.",
  },
  doc_icj_myanmar = {
    title = "ICJ: Myanmar Soykırım Davası",
    type  = "Uluslararası Hukuk",
    color = { 0.94, 0.62, 0.15 },
    body  = "Gambiya 2019'da Myanmar aleyhine Uluslararası Adalet Divanı'nda dava açtı. 2023 itibarıyla dava devam ediyor. ICJ geçici tedbir kararında Myanmar'a Rohingya'yı koruma yükümlülüğü verdi.\n\nKaynak: ICJ Case Filings, UN Documentation.",
  },
  doc_aleppo_barrel = {
    title = "Varil Bombası: Tanımlama ve Kullanım",
    type  = "Savaş Suçu Belgesi",
    color = { 0.28, 0.58, 0.90 },
    body  = "Varil bombası: içine patlayıcı doldurulmuş metal fıçı. Hassas güdüm yok. 2013-2016 arasında Suriye'de en az 18.000 varil bombası atıldığı tahmin ediliyor. BM bu kullanımı savaş suçu olarak nitelendirdi.\n\nKaynak: Airwaves Project, UN Commission of Inquiry on Syria.",
  },
  doc_alan_kurdi = {
    title = "Alan Kurdi ve 2015 Ege Krizi",
    type  = "İnsani Kriz",
    color = { 0.28, 0.58, 0.90 },
    body  = "Eylül 2015'te 3 yaşındaki Alan Kurdi, ailesiyle Bodrum'dan Yunanistan'a geçmeye çalışırken boğuldu. IOM verilerine göre 2015'te Ege'yi geçmeye çalışan 800'den fazla kişi hayatını kaybetti.\n\nKaynak: IOM Missing Migrants, UNHCR Sea Arrivals.",
  },
  doc_vatansiz_rohingya = {
    title = "Vatansızlık: Rohingya",
    type  = "Uluslararası Hukuk",
    color = { 0.90, 0.60, 0.15 },
    body  = "Myanmar 1982 Vatandaşlık Kanunu Rohingyaları resmi olarak tanımlanan 135 etnik gruptan dışlamış ve de facto vatansız kılmıştır. Bu durum eğitim, sağlık ve seyahat haklarını tamamen ortadan kaldırmıştır.\n\nKaynak: UNHCR Statelessness Report, ICJ Myanmar Ruling.",
  },
  doc_tekne_yolculugu = {
    title = "Andaman Denizi Krizleri",
    type  = "Göç Güzergahı",
    color = { 0.90, 0.60, 0.15 },
    body  = "2015 yılında 25.000'den fazla Rohingya ve Bangladeşli, insan kaçakçılarının gemilerinde mahsur kaldı. Tayland, Malezya ve Endonezya gemileri geri çevirdi.\n\nKaynak: IOM Missing Migrants Project.",
  },
  doc_ijop_sistemi = {
    title = "IJOP: Entegre Gözetim",
    type  = "Teknoloji & İnsan Hakları",
    color = { 0.15, 0.72, 0.52 },
    body  = "Xinjiang'daki Entegre Ortak Operasyon Platformu (IJOP); yüz tanıma, DNA, telefon ve hareket verilerini birleştirir. Hikvision ve Huawei bu altyapının temel tedarikçileri — her ikisi de uluslararası borsalarda işlem görmektedir.\n\nKaynak: Australian Strategic Policy Institute, Human Rights Watch 2022.",
  },
  doc_zorla_calisma = {
    title = "Zorunlu Çalışma ve Küresel Tedarik",
    type  = "Ekonomi & İnsan Hakları",
    color = { 0.15, 0.72, 0.52 },
    body  = "ABD Çalışma Bakanlığı verilerine göre Xinjiang'da üretilen pamuğun %85'i Uygur işçiler tarafından toplanıyor. Bu pamuktan üretilen tekstil, küresel hazır giyim zincirine giriyor.\n\nABD 2021'de Uygur Zorla Çalışma Önleme Yasası'nı çıkardı — ancak uygulama sınırlı kaldı.\n\nKaynak: USDOL, Business & Human Rights Resource Centre.",
  },
  doc_silah_gazze = {
    title = "Silah Tedariki: Gazze",
    type  = "Silah Raporu",
    color = { 0.85, 0.30, 0.22 },
    body  = "Stockholm Uluslararası Barış Araştırmaları Enstitüsü (SIPRI) verilerine göre, 2023 yılında Gazze'ye yönelik operasyonlarda kullanılan silahların büyük bölümü ABD, Almanya ve İtalya kaynaklıdır.\n\nKaynaklar: SIPRI Arms Database, Amnesty International Silah Raporları 2023.",
  },
  doc_veto_abd = {
    title = "BM Vetolarının Anatomisi",
    type  = "Hukuki Belge",
    color = { 0.22, 0.52, 0.85 },
    body  = "ABD, 1972'den bu yana BM Güvenlik Konseyi'nde Filistin ile ilgili 45'ten fazla karar tasarısını veto etmiştir. Bu vetolar ateşkes kararlarını, soruşturma komisyonlarını ve insani yardım koridorlarını engellemiştir.\n\nKaynak: UN Security Council Veto List, Global Policy Forum.",
  },
  doc_abluka = {
    title = "Abluka: Rakamlar",
    type  = "İnsani Durum",
    color = { 0.85, 0.65, 0.20 },
    body  = "2007'den bu yana uygulanan abluka kapsamında Gazze'nin deniz, kara ve hava sınırları kontrol altındadır. OCHA verilerine göre 2023 itibarıyla 2,3 milyon kişi kısıtlı su ve elektrikle yaşamakta, gıda ithalatı denetlenmektedir.\n\nKaynak: OCHA Humanitarian Snapshot, WHO Gaza Health Reports.",
  },
  doc_gozetim_cin = {
    title = "Dijital Gözetim Sistemi: Uygurlar",
    type  = "Teknoloji & İnsan Hakları",
    color = { 0.15, 0.65, 0.45 },
    body  = "Çin'in Xinjiang'da uyguladığı 'Entegre Ortak Operasyon Platformu' (IJOP) sistemi; yüz tanıma, DNA toplama, telefon takibi ve hareket kontrolünü birleştirmektedir. Bazı bileşenlerin batılı teknoloji firmalarından temin edildiği belgelenmiştir.\n\nKaynaklar: Australian Strategic Policy Institute, Human Rights Watch 2022.",
  },
  doc_kamp_uyghur = {
    title = "Toplama Kampları: Belgeler",
    type  = "Tanıklık",
    color = { 0.15, 0.65, 0.45 },
    body  = "BM İnsan Hakları Yüksek Komiserliği 2022 raporunda Xinjiang'daki gözaltı tesislerinde 'ciddi insan hakları ihlalleri' yaşandığı tespit edilmiştir. 1 milyondan fazla kişinin keyfi olarak gözaltına alındığı tahmin edilmektedir.\n\nKaynak: OHCHR Xinjiang Assessment 2022.",
  },
  doc_vatansiz_rohingya = {
    title = "Vatansızlık: Rohingya",
    type  = "Uluslararası Hukuk",
    color = { 0.90, 0.60, 0.15 },
    body  = "Myanmar 1982 Vatandaşlık Kanunu Rohingyaları resmi olarak tanımlanan 135 etnik gruptan dışlamış ve de facto vatansız kılmıştır. Bu durum eğitim, sağlık ve seyahat haklarını tamamen ortadan kaldırmıştır.\n\nKaynak: UNHCR Statelessness Report, ICJ Myanmar Ruling.",
  },
  doc_tekne_yolculugu = {
    title = "Andaman Denizi Krizleri",
    type  = "Göç Güzergahı",
    color = { 0.90, 0.60, 0.15 },
    body  = "2015 yılında 25.000'den fazla Rohingya ve Bangladeşli, insan kaçakçılarının gemilerinde mahsur kaldı. Tayland, Malezya ve Endonezya gemileri geri çevirdi. IOM verilerine göre binlerce kişi yolculukta hayatını kaybetti.\n\nKaynak: IOM Missing Migrants Project, UNHCR Sea Arrivals.",
  },
}

function ArchiveState.new()
  return setmetatable({}, ArchiveState)
end

function ArchiveState:enter(data)
  self.fade    = 1
  self.timer   = 0
  self.selected= nil
  self.scroll  = 0

  self.font_title = love.graphics.newFont(26)
  self.font_label = love.graphics.newFont(13)
  self.font_body  = love.graphics.newFont(15)
  self.font_small = love.graphics.newFont(12)
  self.font_mono  = love.graphics.newFont(11)

  -- Kilit açılmış belgeler
  local save_data = SaveSystem.get()
  self.unlocked = save_data.archive or {}
  self._cards   = {}
end

function ArchiveState:update(dt)
  self.timer = self.timer + dt
  if self.fade > 0 then
    self.fade = math.max(0, self.fade - dt * 1.5)
  end
end

function ArchiveState:draw()
  local W, H = Config.vw(), Config.vh()

  love.graphics.setColor(0.04, 0.04, 0.03, 1)
  love.graphics.rectangle("fill", 0, 0, W, H)

  -- Başlık çubuğu
  love.graphics.setColor(0.08, 0.07, 0.06, 1)
  love.graphics.rectangle("fill", 0, 0, W, 60)
  love.graphics.setColor(0.20, 0.18, 0.14, 0.8)
  love.graphics.setLineWidth(0.5)
  love.graphics.line(0, 60, W, 60)

  love.graphics.setFont(self.font_title)
  love.graphics.setColor(0.85, 0.80, 0.65, 1)
  love.graphics.print("Tanıklık Arşivi", 28, 16)

  love.graphics.setFont(self.font_small)
  love.graphics.setColor(0.40, 0.38, 0.32, 1)
  local count_str = #self.unlocked .. " belge kilit açıldı"
  love.graphics.print(count_str, W - self.font_small:getWidth(count_str) - 28, 24)

  -- Geri butonu
  love.graphics.setColor(0.45, 0.42, 0.35, 0.8)
  love.graphics.print("← Geri", 28, H - 32)

  if #self.unlocked == 0 then
    love.graphics.setFont(self.font_label)
    love.graphics.setColor(0.35, 0.33, 0.28, 1)
    local msg = "Henüz belge yok. Bölümleri tamamladıkça arşiv dolacak."
    love.graphics.printf(msg, 40, H/2 - 20, W - 80, "center")
  else
    -- Belge listesi (soldaki panel)
    if not self.selected then
      self:_drawDocList(W, H)
    else
      self:_drawDocDetail(W, H)
    end
  end

  -- Fade
  if self.fade > 0 then
    love.graphics.setColor(0, 0, 0, self.fade)
    love.graphics.rectangle("fill", 0, 0, W, H)
  end

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setLineWidth(1)
end

function ArchiveState:_drawDocList(W, H)
  self._cards = {}
  local card_h = 64
  local pad    = 24
  local y      = 74 + self.scroll

  love.graphics.setFont(self.font_label)

  for i, doc_id in ipairs(self.unlocked) do
    local meta = DOC_META[doc_id]
    if not meta then
      meta = { title = doc_id, type = "Belge", color = { 0.5, 0.5, 0.5 } }
    end

    local by = y + (i-1) * (card_h + 8)
    if by < H - 70 and by > 40 then
      local cr, cg, cb = meta.color[1], meta.color[2], meta.color[3]

      -- Kart arka plan
      love.graphics.setColor(0.08, 0.07, 0.06, 0.95)
      love.graphics.rectangle("fill", pad, by, W - pad*2, card_h, 5)
      -- Sol renk bandı
      love.graphics.setColor(cr, cg, cb, 0.7)
      love.graphics.rectangle("fill", pad, by, 4, card_h, 2)
      -- Çerçeve
      love.graphics.setColor(cr, cg, cb, 0.2)
      love.graphics.setLineWidth(0.5)
      love.graphics.rectangle("line", pad, by, W - pad*2, card_h, 5)

      -- Tip etiketi
      love.graphics.setColor(cr, cg, cb, 0.8)
      love.graphics.print(meta.type, pad + 16, by + 10)

      -- Başlık
      love.graphics.setFont(self.font_body)
      love.graphics.setColor(0.85, 0.80, 0.65, 1)
      love.graphics.print(meta.title, pad + 16, by + 28)
      love.graphics.setFont(self.font_label)

      table.insert(self._cards, { x=pad, y=by, w=W-pad*2, h=card_h, doc_id=doc_id })
    end
  end
end

function ArchiveState:_drawDocDetail(W, H)
  local meta = DOC_META[self.selected]
  if not meta then return end

  local cr, cg, cb = meta.color[1], meta.color[2], meta.color[3]
  local pad = 40

  -- Tip
  love.graphics.setFont(self.font_mono)
  love.graphics.setColor(cr, cg, cb, 0.8)
  love.graphics.print("// " .. meta.type, pad, 74)

  -- Başlık
  love.graphics.setFont(self.font_title)
  love.graphics.setColor(0.88, 0.83, 0.70, 1)
  love.graphics.print(meta.title, pad, 96)

  -- Ayraç
  love.graphics.setColor(cr, cg, cb, 0.3)
  love.graphics.setLineWidth(0.5)
  love.graphics.line(pad, 134, W - pad, 134)

  -- Gövde
  love.graphics.setFont(self.font_body)
  love.graphics.setColor(0.72, 0.68, 0.56, 1)
  love.graphics.printf(meta.body, pad, 148, W - pad*2, "left")

  -- Geri butonu
  love.graphics.setFont(self.font_label)
  love.graphics.setColor(0.55, 0.52, 0.42, 0.9)
  love.graphics.print("← Listeye dön", pad, H - 32)
end

function ArchiveState:_handleTap(x, y)
  local W, H = Config.vw(), Config.vh()

  -- Geri butonu
  if y > H - 48 and x < 150 then
    if self.selected then
      self.selected = nil
    else
      StateManager.switch("menu")
    end
    return
  end

  -- Kart tıklaması
  if not self.selected then
    for _, card in ipairs(self._cards) do
      if x >= card.x and x <= card.x+card.w and
         y >= card.y and y <= card.y+card.h then
        self.selected = card.doc_id
        return
      end
    end
  end
end

function ArchiveState:mousepressed(x, y, btn)
  if btn == 1 then self:_handleTap(x, y) end
end
function ArchiveState:touchpressed(id, x, y, p)
  self:_handleTap(x, y)
end
function ArchiveState:keypressed(key)
  if key=="s" or key=="," then StateManager.push("settings") end
  if key=="n" and self.selected then
    -- Seçili belgenin bölgesini bul ve ağı aç
    local region_map = {
      doc_silah_gazze="gaza", doc_veto_abd="gaza", doc_abluka="gaza",
      doc_gozetim_cin="uyghur", doc_kamp_uyghur="uyghur",
    }
    local r = region_map[self.selected]
    if r then StateManager.push("network", {region_id=r, level=3}) end
  end
  if key == "escape" then
    if self.selected then
      self.selected = nil
    else
      StateManager.switch("menu")
    end
  end
end

return ArchiveState
