# HİCRET

**Zulmü İfşa Et. Yolculuğu Yaşa. Tanıklık Et.**

Filistin'den Doğu Türkistan'a, Arakan'dan Keşmir'e zorla yerinden edilmeyi ve onu mümkün kılan yapıları anlatan narrative-survival oyunu.

**DUT Interdisciplinary Design Agency · LÖVE 2D 11.x (Lua)**

---

## Tarayıcıda Oyna

GitHub Pages otomatik deploy → her `main` push'unda yeniden derlenir.

**Masaüstünde:**
```bash
# https://love2d.org → LÖVE 2D 11.5 kur
love .
```

---

## 6 Bölüm

| Bölge | Tema | Node | Seçim |
|-------|------|------|-------|
| Gazze / Filistin | İşgal, abluka | 29 | 12 |
| Doğu Türkistan | Dijital gözetim | 47 | 16 |
| Arakan / Rohingya | Vatansızlık, deniz | 46 | 14 |
| Suriye | İç savaş, Ege geçişi | 46 | 14 |
| Yemen | Seçilmiş kıtlık | 43 | 14 |
| Keşmir | İletişim ablukası | 40 | 14 |

251 node · 84 seçim · 12 ağ açılış anı · 18 dayanışma seçimi

---

## GitHub Pages Kurulumu (bir kez)

```bash
git clone https://github.com/KULLANICI/hicret.git
cd hicret
git add . && git commit -m "ilk yükleme" && git push
```

GitHub → **Settings → Pages → Source: GitHub Actions**  
GitHub → **Settings → Actions → General → Workflow permissions: Read and write**

Sonraki her push otomatik deploy eder.

---

## Proje Yapısı

```
├── main.lua / conf.lua
├── src/states/          → Oyun durumları
├── src/systems/         → Narrative, Audio, Balance, Touch...
├── src/ui/              → MapRenderer, NetworkUI
├── data/chapters/       → 6 bölüm JSON
├── data/i18n/           → TR/EN diyalog metinleri
├── web/
│   ├── index.html       → Özel web arayüzü
│   └── coi-serviceworker.min.js  → GitHub Pages WASM fix
└── .github/workflows/deploy.yml  → CI/CD
```

---

*"Haber programları istatistik verir; oyun ise sorumluluk yükler."*
