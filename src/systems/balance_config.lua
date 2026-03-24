--[[
  BalanceConfig — Tüm Oyun Dengesi Parametreleri
  
  Bu dosya değiştirilerek kodun hiçbir yerini dokunmadan
  tüm kaynak sistemi, ağırlıklar ve eşikler ayarlanabilir.
  
  Bölüm tasarımcıları buraya bakmalı, motora değil.
--]]

local B = {}

-- ─── Başlangıç Değerleri (bölüme göre override edilebilir) ──────────

B.initial = {
  -- Güven ağı: toplulukla ilişki (0–100)
  trust  = 50,
  -- Yiyecek: günlük hayatta kalma (0–100, log ölçek davranır)
  food   = 10,
  -- Para: kaçış için kritik kaynak (0–100)
  money  = 10,
  -- Moral: psikolojik dayanıklılık (0–100)
  morale = 50,
  -- Belge: geçerli kimlik/kayıt (0 veya 1 ağırlıklı)
  document = 0,
}

-- Bölüme özel başlangıç override'ları
B.chapter_initial = {
  rohingya = { trust=40, food=8,  money=6,  morale=45, document=0 },
  uyghur   = { trust=55, food=12, money=15, morale=50, document=1 },
  syria    = { trust=60, food=14, money=12, morale=55, document=1 },
  gaza     = { trust=50, food=10, money=8,  morale=50, document=0 },
}

-- ─── Kaynak Sınırları ────────────────────────────────────────────────

B.limits = {
  trust    = { min=0,  max=100, soft_min=10  },
  food     = { min=0,  max=100, soft_min=5   },
  money    = { min=0,  max=100, soft_min=3   },
  morale   = { min=0,  max=100, soft_min=15  },
  document = { min=0,  max=10,  soft_min=0   },
}

-- ─── Perde Tipi Pasif Etkileri ───────────────────────────────────────
-- Her node geçişinde otomatik uygulanan zaman baskısı

B.act_drain = {
  life      = { food=-0.6,  morale=-0.3,  money=-0.2  },
  rupture   = { food=-1.2,  morale=-1.5,  money=-0.5  },
  migration = { food=-1.8,  morale=-0.8,  money=-1.0  },
  outcome   = { food=-0.2,  morale= 0.5,  money= 0    },
}

-- ─── Kritik Durum Eşikleri ────────────────────────────────────────────
-- Bu değerlerin altına düşüldüğünde HUD kırmızı yanıp söner

B.critical = {
  food   = 3,    -- açlık uyarısı
  morale = 20,   -- çöküş riski
  money  = 2,    -- hareket kısıtı
  trust  = 10,   -- izolasyon
}

-- Oyun sonu eşikleri (bunların altında "kötü son" tetiklenir)
B.failure_thresholds = {
  food   = 0,
  morale = 0,
}

-- ─── Seçim Efekti Ağırlıkları ─────────────────────────────────────────
-- JSON'daki ham delta değerleri bu çarpanlarla ölçeklenir
-- İnce ayar: bir kaynağı daha değerli/değersiz yapmak için

B.effect_scale = {
  trust    = 1.0,
  food     = 1.2,   -- yiyecek biraz daha değerli
  money    = 1.1,
  morale   = 0.9,   -- moral daha geniş aralıkta salınır
  document = 2.0,   -- belge çok değerli
}

-- ─── Dayanışma Bonusu ─────────────────────────────────────────────────
-- Başkasına yardım eden seçimlerde trust + morale extra artışı

B.solidarity_bonus = {
  trust_mult  = 1.4,   -- trust etkisi %40 artar
  morale_add  = 5,     -- sabit moral bonusu
}

-- ─── Perde Geçiş Normalizasyonu ───────────────────────────────────────
-- Her yeni act başında kaynaklar kısmen normalize edilir
-- (aşırı ceza birikimini engeller)

B.act_transition = {
  -- Perde başında en düşük değeri bu kadar yükselt (eğer altındaysa)
  food_floor   = 4,   -- aç kalmadan migration başlasın
  morale_floor = 18,  -- tamamen çökmeden devam etsin
}

-- ─── Son Değerlendirme (Outcome) ──────────────────────────────────────
-- Sonuç ekranında gösterilen "iyi/kötü/orta" etiket eşikleri

B.outcome_thresholds = {
  -- Toplam skor = ağırlıklı kaynak ortalaması
  excellent = 70,  -- "Hayatta kaldın ve ayakta kaldın"
  good      = 50,  -- "Ağır bedeller ödeyerek geçtin"
  hard      = 30,  -- "Neredeyse kırıldın"
  broken    = 0,   -- "Bu yolculuk seni değiştirdi"
}

-- Kaynak ağırlıkları final skor için
B.outcome_weights = {
  trust    = 0.30,
  morale   = 0.35,
  food     = 0.15,
  money    = 0.10,
  document = 0.10,
}

-- ─── HUD Animasyon Ayarları ───────────────────────────────────────────

B.hud = {
  delta_show_duration = 2.2,    -- sn: delta göstergesinin ekranda kalma süresi
  delta_float_speed   = 22,     -- px/sn: delta değerinin yukarı kayma hızı
  critical_pulse_rate = 3.5,    -- Hz: kritik durum yanıp sönme hızı
  bar_lerp_speed      = 4.0,    -- bar animasyon hızı (lerp katsayısı)
}

-- ─── Seçim Açıklaması Göstergesi ─────────────────────────────────────
-- Hover'da seçim öncesi tahmini etkileri göster (oyuncuya ipucu)

B.choice_hint = {
  show_on_hover = true,         -- hover'da efekt sembolü göster
  threshold_show = 4,           -- bu değerin üzerindeki delta'lar gösterilir
  symbols = {
    big_up   = "▲▲",  -- ≥8 pozitif
    small_up = "▲",   -- 4–7 pozitif
    neutral  = "·",   -- ±3
    small_dn = "▼",   -- 4–7 negatif
    big_dn   = "▼▼",  -- ≥8 negatif
  },
  colors = {
    positive = { 0.45, 0.82, 0.55 },
    neutral  = { 0.50, 0.48, 0.40 },
    negative = { 0.85, 0.38, 0.30 },
  },
}

-- ─── Playtest İstatistik Takibi ───────────────────────────────────────
-- Debug modunda oyun sonunda JSON'a yazılır

B.telemetry = {
  enabled      = true,
  save_path    = "playtest_log.json",
  track_fields = { "trust", "food", "money", "morale" },
}

return B
