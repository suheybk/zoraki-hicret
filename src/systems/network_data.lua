--[[
  NetworkData — Zulüm Ağı Veri Modeli
  
  Her bölge için düğümler (aktörler) ve kenarlar (ilişkiler) tanımlanır.
  Oyun ilerledikçe düğümler ve kenarlar kilit açılır (unlock).
  
  Düğüm tipleri:
    "state"    → devlet / hükümet
    "corp"     → silah/teknoloji şirketi
    "finance"  → banka / fon
    "media"    → medya kuruluşu
    "law"      → hukuki mekanizma (BM, mahkeme)
    "tech"     → gözetim teknolojisi
    "ngo"      → NGO / insani örgüt (kötü amaçlı)
    "victim"   → mağdur taraf (ana karakter noktası)
  
  Kenar tipleri:
    "arms"     → silah satışı / tedarik
    "finance"  → finansal destek / kredi
    "veto"     → hukuki engel (BM veto)
    "silence"  → medya suskunluğu / sansür
    "tech"     → teknoloji transferi / gözetim satışı
    "sanction" → yaptırım / baskı (mağdura)
    "aid"      → insani yardım engeli
    "lobby"    → lobi / siyasi baskı
--]]

local NetworkData = {}

-- ─── Renk paleti (tip bazında) ──────────────────────────────────────
NetworkData.TYPE_COLORS = {
  state   = { 0.85, 0.35, 0.25 },   -- kırmızımsı: devlet güç
  corp    = { 0.85, 0.60, 0.20 },   -- amber: şirket
  finance = { 0.45, 0.75, 0.45 },   -- yeşil: para
  media   = { 0.55, 0.55, 0.88 },   -- mavi: medya
  law     = { 0.70, 0.45, 0.80 },   -- mor: hukuk
  tech    = { 0.30, 0.80, 0.75 },   -- teal: teknoloji
  ngo     = { 0.80, 0.55, 0.35 },   -- turuncu: kirli NGO
  victim  = { 0.90, 0.88, 0.75 },   -- krem: mağdur
}

NetworkData.EDGE_COLORS = {
  arms     = { 0.85, 0.25, 0.20 },
  finance  = { 0.40, 0.75, 0.40 },
  veto     = { 0.70, 0.40, 0.80 },
  silence  = { 0.50, 0.50, 0.80 },
  tech     = { 0.25, 0.80, 0.75 },
  sanction = { 0.85, 0.50, 0.20 },
  aid      = { 0.80, 0.70, 0.30 },
  lobby    = { 0.70, 0.35, 0.55 },
}

-- ─── Bölge Ağları ────────────────────────────────────────────────────

NetworkData.regions = {}

-- ── GAZZE / FİLİSTİN ──────────────────────────────────────────────
NetworkData.regions["gaza"] = {
  title = "Gazze: Zulüm Ağı",

  nodes = {
    -- Mağdur taraf
    { id="gazze_halk",  label="Gazze Halkı",       type="victim",  x=0.50, y=0.50, unlock=0 },

    -- Devletler
    { id="usa",         label="ABD",                type="state",   x=0.15, y=0.18, unlock=0 },
    { id="israel",      label="İsrail",             type="state",   x=0.28, y=0.30, unlock=0 },
    { id="germany",     label="Almanya",            type="state",   x=0.18, y=0.35, unlock=1 },
    { id="uk",          label="Birleşik Krallık",   type="state",   x=0.10, y=0.45, unlock=1 },
    { id="egypt",       label="Mısır",              type="state",   x=0.38, y=0.70, unlock=2 },

    -- Şirketler (silah)
    { id="boeing",      label="Boeing",             type="corp",    x=0.80, y=0.15, unlock=1 },
    { id="rtx",         label="RTX (Raytheon)",     type="corp",    x=0.88, y=0.30, unlock=1 },
    { id="bae",         label="BAE Systems",        type="corp",    x=0.80, y=0.45, unlock=2 },

    -- Finans
    { id="jpmorgan",    label="JPMorgan",           type="finance", x=0.75, y=0.62, unlock=2 },
    { id="blackrock",   label="BlackRock",          type="finance", x=0.85, y=0.72, unlock=3 },

    -- Medya
    { id="media_west",  label="Batı Medyası",       type="media",   x=0.20, y=0.62, unlock=1 },
    { id="meta_censor", label="Meta/Sansür",        type="tech",    x=0.12, y=0.75, unlock=2 },

    -- Hukuk
    { id="unsc",        label="BM Güv. Kon.",       type="law",     x=0.50, y=0.18, unlock=0 },
    { id="icc",         label="UCM",                type="law",     x=0.62, y=0.28, unlock=2 },
  },

  edges = {
    -- Silah akışı
    { from="usa",        to="israel",      type="arms",    label="F-35, hassas bombalar", unlock=0 },
    { from="boeing",     to="israel",      type="arms",    label="JDAM güdüm kitleri",    unlock=1 },
    { from="rtx",        to="israel",      type="arms",    label="Patriot, Iron Dome",    unlock=1 },
    { from="bae",        to="israel",      type="arms",    label="Askeri ekipman",        unlock=2 },
    { from="germany",    to="israel",      type="arms",    label="Denizaltı, silah ihracı",unlock=1 },
    { from="uk",         to="israel",      type="arms",    label="Uçak parçaları",        unlock=1 },

    -- Finansal bağlar
    { from="usa",        to="boeing",      type="finance", label="Savunma kontratları",   unlock=1 },
    { from="jpmorgan",   to="rtx",         type="finance", label="Yatırım / hisse",       unlock=2 },
    { from="blackrock",  to="boeing",      type="finance", label="Yatırım fonu",          unlock=3 },

    -- Hukuki engeller
    { from="usa",        to="unsc",        type="veto",    label="45+ veto (1972–)",      unlock=0 },
    { from="unsc",       to="gazze_halk",  type="sanction", label="Ateşkes engeli",       unlock=0 },
    { from="icc",        to="israel",      type="law",     label="Tutuklama müzekkeresi", unlock=2 },

    -- Medya suskunluğu
    { from="media_west", to="gazze_halk",  type="silence", label="Kasıtlı dil seçimi",   unlock=1 },
    { from="meta_censor",to="gazze_halk",  type="silence", label="Filistin içerik silme", unlock=2 },

    -- İsrail → Mağdur
    { from="israel",     to="gazze_halk",  type="sanction", label="Abluka, bombardıman", unlock=0 },

    -- Mısır — sınır kapısı kontrolü
    { from="egypt",      to="gazze_halk",  type="aid",     label="Rafah kapısı kısıtı",  unlock=2 },

    -- Lobi
    { from="boeing",     to="usa",         type="lobby",   label="Savunma lobisi",        unlock=1 },
    { from="rtx",        to="usa",         type="lobby",   label="Kongre bağışları",      unlock=2 },
  },
}

-- ── DOĞU TÜRKİSTAN / UYGURLAR ───────────────────────────────────────
NetworkData.regions["uyghur"] = {
  title = "Doğu Türkistan: Zulüm Ağı",

  nodes = {
    { id="uyghur_halk",  label="Uygur Halkı",       type="victim",  x=0.50, y=0.50, unlock=0 },
    { id="ccp",          label="ÇKP / Çin Devleti", type="state",   x=0.22, y=0.22, unlock=0 },
    { id="xinjiang_gov", label="Xinjiang Yönetimi",  type="state",   x=0.35, y=0.35, unlock=0 },
    { id="huawei",       label="Huawei",             type="tech",    x=0.78, y=0.20, unlock=1 },
    { id="hikvision",    label="Hikvision",          type="tech",    x=0.85, y=0.35, unlock=1 },
    { id="dahua",        label="Dahua Tech.",        type="tech",    x=0.80, y=0.50, unlock=2 },
    { id="alibaba",      label="Alibaba Cloud",      type="tech",    x=0.72, y=0.65, unlock=2 },
    { id="un_hrc",       label="BM İnsan Hakları",   type="law",     x=0.50, y=0.18, unlock=1 },
    { id="ioc",          label="Olimpiyat Kom.",     type="ngo",     x=0.18, y=0.62, unlock=2 },
    { id="west_brands",  label="Batılı Markalar",    type="corp",    x=0.20, y=0.45, unlock=2 },
    { id="cotton_supply",label="Pamuk Tedarik Zinciri",type="finance",x=0.35,y=0.70, unlock=3 },
    { id="us_commerce",  label="ABD Ticaret Bak.",   type="state",   x=0.12, y=0.30, unlock=2 },
  },

  edges = {
    { from="ccp",         to="xinjiang_gov",  type="sanction", label="Politika direktifi",    unlock=0 },
    { from="xinjiang_gov",to="uyghur_halk",   type="sanction", label="IJOP gözetim, kamplar", unlock=0 },
    { from="huawei",      to="xinjiang_gov",  type="tech",     label="Yüz tanıma altyapısı",  unlock=1 },
    { from="hikvision",   to="xinjiang_gov",  type="tech",     label="Kamera ağı, CCTV",      unlock=1 },
    { from="dahua",       to="xinjiang_gov",  type="tech",     label="Akıllı şehir sistemleri",unlock=2 },
    { from="alibaba",     to="ccp",           type="tech",     label="Bulut veri paylaşımı",  unlock=2 },
    { from="un_hrc",      to="ccp",           type="silence",  label="Rapor sonrası sessizlik",unlock=1 },
    { from="ioc",         to="ccp",           type="finance",  label="2022 Pekin Olimpiyatları",unlock=2 },
    { from="west_brands", to="cotton_supply", type="finance",  label="Zorla çalışma zinciri", unlock=2 },
    { from="cotton_supply",to="uyghur_halk",  type="sanction", label="Zorla çalıştırma",      unlock=3 },
    { from="us_commerce", to="huawei",        type="sanction", label="Kısmi yaptırım listesi",unlock=2 },
    { from="ccp",         to="uyghur_halk",   type="sanction", label="Kültürel asimilasyon",  unlock=0 },
  },
}

-- ── SURİYE ──────────────────────────────────────────────────────────
NetworkData.regions["syria"] = {
  title = "Suriye: Zulüm Ağı",

  nodes = {
    { id="syria_halk",   label="Suriye Halkı",       type="victim",  x=0.50, y=0.50, unlock=0 },
    { id="assad",        label="Esad Rejimi",         type="state",   x=0.28, y=0.28, unlock=0 },
    { id="russia",       label="Rusya",               type="state",   x=0.20, y=0.18, unlock=0 },
    { id="iran",         label="İran",                type="state",   x=0.38, y=0.20, unlock=1 },
    { id="rosoboron",    label="Rosoboronexport",     type="corp",    x=0.80, y=0.22, unlock=1 },
    { id="barrel_bomb",  label="Varil Bomb Üreticileri",type="corp",  x=0.82, y=0.40, unlock=2 },
    { id="russia_media", label="RT / Sputnik",        type="media",   x=0.15, y=0.55, unlock=1 },
    { id="unsc_russia",  label="BM Güv. Kon.",        type="law",     x=0.50, y=0.18, unlock=0 },
    { id="white_helmets",label="Beyaz Miğferler",     type="ngo",     x=0.72, y=0.65, unlock=2 },
    { id="oil_trade",    label="Petrol Ticaret Ağı",  type="finance", x=0.35, y=0.72, unlock=3 },
  },

  edges = {
    { from="russia",      to="assad",       type="arms",    label="Hava saldırısı, S-400",  unlock=0 },
    { from="iran",        to="assad",       type="arms",    label="Milis desteği, silah",   unlock=1 },
    { from="rosoboron",   to="russia",      type="finance", label="Silah ihracat geliri",   unlock=1 },
    { from="barrel_bomb", to="assad",       type="arms",    label="Varil bomba üretimi",    unlock=2 },
    { from="russia",      to="unsc_russia", type="veto",    label="17+ veto (2011–)",        unlock=0 },
    { from="unsc_russia", to="syria_halk",  type="sanction",label="Soruşturma engeli",      unlock=0 },
    { from="russia_media",to="syria_halk",  type="silence", label="Dezenformasyon",         unlock=1 },
    { from="oil_trade",   to="assad",       type="finance", label="Savaş ekonomisi geliri", unlock=3 },
    { from="assad",       to="syria_halk",  type="sanction",label="Kimyasal silah, abluka", unlock=0 },
  },
}

-- ─── API ──────────────────────────────────────────────────────────────

--- Bölge verisi döndür
function NetworkData.get(region_id)
  return NetworkData.regions[region_id]
end

--- Kilidi açık düğüm/kenar listesi (unlock_level'a göre filtrele)
function NetworkData.getUnlocked(region_id, level)
  local net = NetworkData.regions[region_id]
  if not net then return nil end

  local nodes, edges = {}, {}
  for _, n in ipairs(net.nodes) do
    if n.unlock <= level then table.insert(nodes, n) end
  end
  for _, e in ipairs(net.edges) do
    if e.unlock <= level then table.insert(edges, e) end
  end
  return { title=net.title, nodes=nodes, edges=edges }
end

--- Bölgedeki maksimum kilit seviyesi
function NetworkData.maxLevel(region_id)
  local net = NetworkData.regions[region_id]
  if not net then return 0 end
  local max = 0
  for _, n in ipairs(net.nodes) do max = math.max(max, n.unlock) end
  for _, e in ipairs(net.edges) do max = math.max(max, e.unlock) end
  return max
end

-- ── ROHINGYA / ARAKAN ────────────────────────────────────────────────
NetworkData.regions["rohingya"] = {
  title = "Rohingya: Zulüm Ağı",

  nodes = {
    { id="rohingya_halk",  label="Rohingya Halkı",      type="victim",  x=0.50, y=0.52, unlock=0 },
    { id="myanmar_gov",    label="Myanmar Hükümeti",     type="state",   x=0.22, y=0.22, unlock=0 },
    { id="military",       label="Tatmadaw (Ordu)",      type="state",   x=0.30, y=0.35, unlock=0 },
    { id="rakhine_militia",label="Rakhine Milisleri",    type="corp",    x=0.40, y=0.42, unlock=0 },
    { id="china",          label="Çin",                  type="state",   x=0.15, y=0.18, unlock=1 },
    { id="india",          label="Hindistan",            type="state",   x=0.20, y=0.32, unlock=1 },
    { id="asean",          label="ASEAN",                type="ngo",     x=0.15, y=0.48, unlock=2 },
    { id="unsc_block",     label="BM Güv. Kon.",         type="law",     x=0.50, y=0.18, unlock=1 },
    { id="cnooc",          label="Çin Enerji Firmaları", type="finance", x=0.80, y=0.25, unlock=2 },
    { id="gas_pipeline",   label="Kyaukphyu Boru Hattı", type="finance", x=0.75, y=0.40, unlock=3 },
    { id="unhcr_cox",      label="BMMYK Cox's Bazar",    type="ngo",     x=0.70, y=0.68, unlock=1 },
  },

  edges = {
    { from="military",      to="rohingya_halk",  type="sanction", label="Etnik kıyım, köy yakma",  unlock=0 },
    { from="myanmar_gov",   to="military",       type="arms",     label="Tatmadaw'a destek",        unlock=0 },
    { from="rakhine_militia",to="rohingya_halk", type="sanction", label="Sivil şiddet",             unlock=0 },
    { from="china",         to="unsc_block",     type="veto",     label="BM kararlarına veto",      unlock=1 },
    { from="china",         to="myanmar_gov",    type="arms",     label="Silah tedariki",           unlock=1 },
    { from="india",         to="myanmar_gov",    type="finance",  label="Altyapı yatırımı",         unlock=1 },
    { from="asean",         to="myanmar_gov",    type="silence",  label="'İç mesele' söylemi",      unlock=2 },
    { from="cnooc",         to="gas_pipeline",   type="finance",  label="Kyaukphyu gaz projesi",    unlock=2 },
    { from="gas_pipeline",  to="myanmar_gov",    type="finance",  label="Gelir akışı",              unlock=3 },
    { from="unsc_block",    to="rohingya_halk",  type="sanction", label="Hesap sorulamaması",       unlock=1 },
    { from="unhcr_cox",     to="rohingya_halk",  type="aid",      label="Sınırlı insani yardım",    unlock=1 },
  },
}

-- ── YEMEN ────────────────────────────────────────────────────────────
NetworkData.regions["yemen"] = {
  title = "Yemen: Zulüm Ağı",

  nodes = {
    { id="yemen_halk",       label="Yemen Halkı",          type="victim",  x=0.50, y=0.52, unlock=0 },
    { id="houthi",           label="Husiler",              type="state",   x=0.30, y=0.35, unlock=0 },
    { id="saudi_coalition",  label="Suudi Koalisyonu",     type="state",   x=0.22, y=0.22, unlock=0 },
    { id="uae",              label="BAE",                  type="state",   x=0.30, y=0.18, unlock=0 },
    { id="usa_arms",         label="ABD Silah Endüstrisi", type="corp",    x=0.80, y=0.18, unlock=1 },
    { id="uk_arms",          label="İngiltere Silah İhr.", type="corp",    x=0.88, y=0.28, unlock=1 },
    { id="iran_houthi",      label="İran",                 type="state",   x=0.15, y=0.38, unlock=1 },
    { id="arms_dealers",     label="Silah Aracıları",      type="corp",    x=0.18, y=0.55, unlock=2 },
    { id="hodeidah_port",    label="Hudeyda Limanı",       type="ngo",     x=0.50, y=0.72, unlock=1 },
    { id="wfp_yemen",        label="WFP Yemen",            type="ngo",     x=0.65, y=0.72, unlock=1 },
    { id="oil_interests",    label="Petrol Çıkarları",     type="finance", x=0.78, y=0.55, unlock=3 },
  },

  edges = {
    { from="saudi_coalition", to="yemen_halk",   type="arms",     label="Hava saldırıları, abluka",   unlock=0 },
    { from="uae",             to="saudi_coalition",type="arms",   label="Lojistik, askeri",            unlock=0 },
    { from="usa_arms",        to="saudi_coalition",type="arms",   label="F-15, güdümlü bombalar",      unlock=1 },
    { from="uk_arms",         to="saudi_coalition",type="arms",   label="Typhoon uçağı, füzeler",      unlock=1 },
    { from="iran_houthi",     to="houthi",        type="arms",    label="Silah transferi",             unlock=1 },
    { from="arms_dealers",    to="iran_houthi",   type="finance", label="Kaçak silah ağı",             unlock=2 },
    { from="houthi",          to="yemen_halk",    type="sanction",label="Toprak kontrolü, vergi",      unlock=0 },
    { from="saudi_coalition", to="hodeidah_port", type="sanction",label="Liman ablukası",              unlock=1 },
    { from="hodeidah_port",   to="yemen_halk",    type="aid",     label="Bloke edilen insani yardım",  unlock=1 },
    { from="wfp_yemen",       to="yemen_halk",    type="aid",     label="Sınırlı gıda dağıtımı",       unlock=1 },
    { from="oil_interests",   to="saudi_coalition",type="finance", label="Petrol geliri",               unlock=3 },
  },
}

-- ── KEŞMİR ────────────────────────────────────────────────────────────
NetworkData.regions["kashmir"] = {
  title = "Keşmir: Zulüm Ağı",

  nodes = {
    { id="kashmir_halk",   label="Keşmir Halkı",       type="victim",  x=0.50, y=0.52, unlock=0 },
    { id="india_gov",      label="Hindistan Hükümeti", type="state",   x=0.22, y=0.22, unlock=0 },
    { id="military_india", label="Hindistan Ordusu",   type="state",   x=0.32, y=0.32, unlock=0 },
    { id="psa_law",        label="PSA Yasası",         type="law",     x=0.42, y=0.22, unlock=0 },
    { id="india_media",    label="Hindistan Medyası",  type="media",   x=0.18, y=0.48, unlock=1 },
    { id="pakistan_tension",label="Pakistan",          type="state",   x=0.78, y=0.30, unlock=1 },
    { id="china_trade",    label="Çin Ticaret Çıkarı", type="finance", x=0.88, y=0.20, unlock=2 },
    { id="un_ignored",     label="BM (Görmezden)",     type="law",     x=0.50, y=0.18, unlock=1 },
    { id="article_370",    label="370. Madde Kaldırma",type="law",     x=0.62, y=0.42, unlock=0 },
    { id="tech_blackout",  label="İletişim Ablukası",  type="tech",    x=0.72, y=0.58, unlock=0 },
    { id="settler_law",    label="Yerleşimci Politika",type="state",   x=0.38, y=0.68, unlock=2 },
  },

  edges = {
    { from="india_gov",     to="psa_law",         type="law",      label="Keyfi gözaltı aracı",       unlock=0 },
    { from="india_gov",     to="article_370",     type="law",      label="5 Ağustos 2019 kararnamesi", unlock=0 },
    { from="india_gov",     to="tech_blackout",   type="tech",     label="213 gün internet yasağı",    unlock=0 },
    { from="military_india",to="kashmir_halk",    type="sanction", label="Sokağa çıkma, kontrol",     unlock=0 },
    { from="psa_law",       to="kashmir_halk",    type="sanction", label="Suçsuz gözaltı, 2 yıla kadar",unlock=0 },
    { from="article_370",   to="settler_law",     type="law",      label="Dışarıdan arazi alımı",      unlock=2 },
    { from="settler_law",   to="kashmir_halk",    type="sanction", label="Demografik değişim riski",   unlock=2 },
    { from="india_media",   to="kashmir_halk",    type="silence",  label="Tek yanlı haber çerçevesi",  unlock=1 },
    { from="china_trade",   to="india_gov",       type="lobby",    label="Ekonomik ilişki, sessizlik", unlock=2 },
    { from="un_ignored",    to="kashmir_halk",    type="silence",  label="Plebisit vaadi 75 yıldır",   unlock=1 },
    { from="pakistan_tension",to="india_gov",     type="arms",     label="Çift cepheli gerilim",       unlock=1 },
    { from="tech_blackout", to="kashmir_halk",    type="sanction", label="Bilgiye erişim engeli",      unlock=0 },
  },
}

return NetworkData
