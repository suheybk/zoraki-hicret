# HİCRET — Geliştirici Notu
**DUT Interdisciplinary Design Agency**
Tarih: Mart 2026 | Motor: LÖVE 2D 11.4 (LuaJIT / Lua 5.1)

---

## PROJE NEDİR?

Filistin'den Doğu Türkistan'a, Arakan'dan Keşmir'e uzanan zorla yerinden edilmeyi
ve onu mümkün kılan yapıları anlatan narrative-survival oyunu.

Oyun hem İslâm dünyasının kanayan yaralarını hem de evrensel baskı sistemlerini
konu alır. Amaç: "Sen orada olsaydın ne yapardın?" sorusunu somutlaştırmak.

---

## NE YAPILDI — TAM GEÇMİŞ

### TEMEL SİSTEMLER (her bölümde ortak çalışır)

| Sistem | Dosya | Açıklama |
|--------|-------|----------|
| StateManager | src/systems/state_manager.lua | Sonlu durum makinesi, push/pop stack |
| NarrativeEngine | src/systems/narrative_engine.lua | JSON tabanlı diyalog ağacı motoru |
| BalanceEngine | src/systems/balance_engine.lua | Kaynak dengesi, dayanışma bonusu, final skor |
| BalanceConfig | src/systems/balance_config.lua | Tüm sayısal parametreler tek yerde |
| AudioManager | src/systems/audio_manager.lua | Ambiyans cross-fade, SFX havuzu |
| Synth | src/systems/synth.lua | PCM ses sentezi — harici ses dosyası YOK |
| I18n | src/systems/i18n.lua | TR/EN/AR çok dil, bölüm bazlı JSON yükleme |
| SaveSystem | src/systems/save_system.lua | love.filesystem, web'de IndexedDB |
| TouchManager | src/systems/touch_manager.lua | Tap, double-tap, long-press, swipe, pan, pinch |
| MapCamera | src/systems/map_camera.lua | Pan/pinch-zoom kamera, fling momentum |
| NetworkData | src/systems/network_data.lua | 6 bölge zulüm ağı verisi (kilitseviye) |
| MapRenderer | src/ui/map_renderer.lua | Prosedürel kıta haritası — harici görsel YOK |
| NetworkUI | src/ui/network_ui.lua | Zulüm ağı görsel renderer, reveal animasyonu |

### DURUM (STATE) AKIŞI

```
Boot
  └─► WorldMap (harita + bölge seçimi)
        └─► Chapter (bölüm yöneticisi + perde sırası)
              └─► Act (diyalog + seçim + HUD)
                    ├─► NetworkReveal (sinematik ağ açılışı — push/pop)
                    └─► [bölüm bitti]
                          └─► Outcome (sonuç + belge açılışı)
                                ├─► Archive (tanıklık arşivi)
                                ├─► Network (tam ekran ağ görüntüleyici)
                                └─► WorldMap

Settings  ←─ her yerden [ S ] ile push/pop
```

### İÇERİK — 6 BÖLÜM

| Bölge | Karakter | Tema | Node | Seçim | Ağ Açılışı |
|-------|----------|------|------|-------|------------|
| Gazze | Adsız aile | İşgal, abluka | 29 | 12 | 2 |
| Doğu Türkistan | Aysha | Dijital gözetim, asimilasyon | 47 | 16 | 2 |
| Arakan / Rohingya | Nur | Vatansızlık, deniz yolculuğu | 46 | 14 | 2 |
| Suriye | Tarık | İç savaş, Ege geçişi | 46 | 14 | 2 |
| Yemen | Maryam | Vekâlet savaşı, seçilmiş kıtlık | 43 | 14 | 2 |
| Keşmir | Tariq | İletişim ablukası, sessiz direniş | 40 | 14 | 2 |
| **TOPLAM** | | | **251** | **84** | **12** |

Her bölümde:
- 3 perde: Yaşam → Kırılma → Hicret
- 2 sinematik zulüm ağı açılışı (farklı seviyelerde)
- 18 dayanışma seçimi (başkasına yardım → güven/moral bonusu)
- Türkçe diyalog metinleri (JSON, kod dışında)

### ARŞİV — 12 BELGE

Her bölüm tamamlandığında gerçek kaynaklara dayalı belgeler açılır:
SIPRI silah verileri, BM kayıtları, Amnesty International raporları,
ICJ mahkeme kararları, IOM göç istatistikleri, BM İnsan Hakları raporları.

### KAYNAK SİSTEMİ (Balans)

4 kaynak: Güven (0–100), Yiyecek (0–100), Para (0–100), Moral (0–100)

- Bölüme özel başlangıç değerleri (Rohingya en zor: food=8, money=6)
- Perde başı pasif tüketim (Migration en ağır: food–1.8/node)
- Kritik eşik altında HUD kırmızı pulse
- Seçim hover'ında tahmini etki sembolü (▲▼)
- Delta animasyonu: +12 ▲ HUD üzerinde süzülür
- Telemetri: playtest_log.json'a oturum verisi yazılır

### WEB / PLATFORM

- love.js (Emscripten) ile WASM derleme
- GitHub Actions CI/CD: main push → otomatik deploy
- coi-serviceworker.min.js: GitHub Pages SharedArrayBuffer fix
- Mobil: pinch-zoom harita, fling momentum, dokunmatik tüm gestureler

---

## ŞUAN NEREDE?

### ÇALIŞIYOR ✓
- Tüm 6 bölüm oynanabilir (lokal)
- Dünya haritası, bölge seçimi, pan/zoom
- Diyalog sistemi (typewriter, seçimler, HUD)
- Ses sistemi (prosedürel PCM)
- Zulüm ağı görüntüleyici
- Arşiv ekranı
- Ayarlar (ses, dil)
- GitHub Pages deploy pipeline

### EKSİK / SORUNLU ✗
- **Ana menü yok**: Oyun direkt boot → dünya haritasına giriyor
  "Yeni Oyun / Devam Et / Hakkında" ekranı gerekiyor
- **Bölüm kilit açma**: Gaza bitince Uygur otomatik açılıyor (YENİ DÜZELTILDI)
  ama önceki kayıtlarda sadece Gaza açık — save sıfırlama gerekebilir
- **Türkçe özel karakter**: Typewriter UTF-8 sorunu çözüldü (Lua 5.1 uyumlu)
- **GitHub Pages**: coi-serviceworker eklendi, push sonrası test edilmedi
- **Compatibility warning**: conf.lua 11.5 → 11.4 düşürüldü (love.js uyumu)

---

## NEREYE GİDECEĞİZ — ÖNCELIK SIRASI

### HEMEN YAPILMASI GEREKEN

**1. Ana Menü (MainMenuState)**
```
Ekranlar:
  - Başlangıç: HİCRET logosu + "Başla / Devam Et / Hakkında"
  - Hakkında: kısa proje notu + kaynak atfı
  - Yeni oyun: SaveSystem.reset() + WorldMap
  - Devam et: Mevcut ilerlemeyle WorldMap
```

**2. Save sistemi düzeltmesi**
```
Mevcut kayıtlarda sadece "gaza" açık.
Geliştirme sırasında Ctrl+U ile debug açıyorduk.
Yeni oyuncular için: Gaza açık başlıyor, bitince Uygur açılıyor. ✓
Eski kayıtlar sorunlu → "Yeni Oyun" butonu ile resetleme.
```

### ORTA VADELİ

**3. Outcome ekranı iyileştirmesi**
- "Haritaya Dön" butonunu daha belirgin yap
- Tamamlanan bölümde ✓ işareti worldmap'te görünüyor ama
  outcome'da "sıradaki bölüm açıldı" bildirimi yok

**4. WorldMap görsel kalitesi**
- Şu an prosedürel vektör — gerçek harita PNG ile çok daha iyi görünür
- Bölge noktalarının zoom'da sabit boyut kalması tutarsız

**5. İngilizce içerik**
- Uygur bölümünün EN versiyonu var (chapter_uyghur_en.json)
- Diğer 5 bölümün EN versiyonu YOK
- AR (Arapça) çeviri hiç yok

### UZUN VADELİ

**6. Android APK**
- love-android ile wrap: projeye bakılacak
- touch kontroller hazır, zoom/pan çalışıyor

**7. Yeni bölümler (potansiyel)**
- Bosna / Srebrenitsa (tarihsel)
- Çeçenistan
- Evrensel bölüm: farklı kıtalardaki zorunlu göç

**8. Ses / Görsel**
- Gerçek ambiyans ses dosyaları (şu an PCM sentez)
- Bölüme özel arka plan görselleri (şu an düz renk)
- Karakter illüstrasyonları (isteğe bağlı)

**9. NGO / Platform ortaklıkları**
- UNHCR, Amnesty, Human Rights Watch ile içerik doğrulaması
- Eğitim paketi versiyonu (okul sürümü)

---

## DOSYA HARİTASI

```
hicret/
├── main.lua              ← Giriş, tüm callback'ler
├── conf.lua              ← LÖVE ayarları (versiyon: 11.4)
│
├── src/
│   ├── states/           ← Oyun durumları
│   │   ├── boot.lua          - Yükleme ekranı
│   │   ├── world_map.lua     - Harita + bölge seçimi [GELİŞTİRİLECEK]
│   │   ├── chapter.lua       - Perde yöneticisi + kilit açma [DÜZELTİLDİ]
│   │   ├── act.lua           - Diyalog + HUD + delta anim
│   │   ├── outcome.lua       - Bölüm sonu + arşiv belgesi
│   │   ├── archive.lua       - Belge okuyucu
│   │   ├── network.lua       - Tam ekran ağ görüntüleyici
│   │   ├── network_reveal.lua- Sinematik ağ açılışı (push/pop)
│   │   └── settings.lua      - Ses + dil ayarları
│   │   [EKSİK: main_menu.lua]
│   │
│   ├── systems/          ← Motor sistemleri
│   │   ├── state_manager.lua
│   │   ├── narrative_engine.lua
│   │   ├── balance_engine.lua + balance_config.lua
│   │   ├── audio_manager.lua + synth.lua
│   │   ├── i18n.lua
│   │   ├── save_system.lua
│   │   ├── touch_manager.lua
│   │   ├── map_camera.lua
│   │   └── network_data.lua
│   │
│   └── ui/               ← Görsel bileşenler
│       ├── map_renderer.lua   - Prosedürel kıta haritası
│       └── network_ui.lua     - Zulüm ağı renderer
│
├── data/
│   ├── chapters/         ← 6 bölüm JSON (Lua'ya dokunmadan düzenlenebilir)
│   │   ├── gaza.json
│   │   ├── uyghur.json
│   │   ├── rohingya.json
│   │   ├── syria.json
│   │   ├── yemen.json
│   │   └── kashmir.json
│   └── i18n/             ← Diyalog metinleri
│       ├── tr.json + en.json          - UI metinleri
│       ├── chapter_*_tr.json          - Her bölüm Türkçe
│       └── chapter_uyghur_en.json     - Sadece Uygur EN var
│
└── web/
    ├── index.html                     - Özel yükleme ekranı
    └── coi-serviceworker.min.js       - GitHub Pages WASM fix

.github/workflows/deploy.yml           - CI/CD: push → GitHub Pages
.gitignore
```

---

## KRİTİK TEKNİK NOTLAR

### Lua 5.1 Uyumluluk
LÖVE 11.x LuaJIT kullanır (Lua 5.1). Dikkat edilmesi gerekenler:
- `utf8` kütüphanesi YOK → `utf8_len()` / `utf8_sub()` elle yazıldı (act.lua)
- `x and x()` statement olarak geçersiz → `if x then x() end` kullan
- `//` integer division yok → `math.floor(a/b)` kullan

### return Sonrası Kod Hatası
Daha önce `cat >>` ile eklenen fonksiyonlar `return` sonrasına düştü.
Bu Lua'da syntax hatasıdır. Tüm düzeltildi ama dikkat et.

### Yeni Bölüm veya Diyalog Eklemek
1. `data/chapters/yeni.json` oluştur (mevcut bölümü şablon al)
2. `data/i18n/chapter_yeni_tr.json` ile diyalog metinlerini yaz
3. `src/systems/network_data.lua` içine ağ verisini ekle
4. `src/states/world_map.lua` içindeki `REGION_DEFS` tablosuna lon/lat ekle
5. `src/states/chapter.lua` içindeki `chapter_order` listesine ekle
6. Lua kodu değişmez — sadece JSON/veri dosyaları

### Debug Kısayolları (lokal)
| Tuş | Fonksiyon |
|-----|-----------|
| Ctrl+U | Tüm bölgeleri aç |
| S | Ayarlar |
| A | Arşiv |
| N | Zulüm ağı (Gaza, seviye 3) |
| R | Harita zoom sıfırla |
| ESC | Geri |

---

*"Haber programları istatistik verir; oyun ise sorumluluk yükler."*
