#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────
#  HİCRET — Web Derleme Scripti
#  Kullanım: ./build_web.sh [--serve] [--open]
#
#  Gereksinimler:
#    npm install -g love.js
#    (opsiyonel) Python 3 veya Node.js — yerel sunucu için
# ─────────────────────────────────────────────────────────────────────

set -e

GAME_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${GAME_DIR}/build_web"
LOVE_FILE="${GAME_DIR}/hicret.love"
TITLE="Hicret"
MEMORY=67108864   # 64 MB

SERVE=false
OPEN=false

for arg in "$@"; do
  case $arg in
    --serve) SERVE=true ;;
    --open)  OPEN=true  ;;
    --clean) rm -rf "$BUILD_DIR" "$LOVE_FILE"; echo "Temizlendi."; exit 0 ;;
  esac
done

# ── 1. Gereksinimler ────────────────────────────────────────────────
echo "┌─ Gereksinim kontrolü"
if ! command -v love.js &> /dev/null; then
  echo "│  HATA: love.js bulunamadı. Kurmak için:"
  echo "│    npm install -g love.js"
  exit 1
fi
LOVEJS_VER=$(love.js --version 2>/dev/null || echo "bilinmiyor")
echo "│  love.js: $LOVEJS_VER  ✓"
echo "└─ Tamam"
echo ""

# ── 2. .love paketi ─────────────────────────────────────────────────
echo "┌─ .love paketi hazırlanıyor"
cd "$GAME_DIR"

zip -9 -r "$LOVE_FILE" . \
  --exclude "build_web/*" \
  --exclude ".github/*" \
  --exclude "*.sh" \
  --exclude "*.zip" \
  --exclude "*.love" \
  --exclude ".git/*" \
  --exclude "__pycache__/*" \
  --exclude "*.pyc" \
  --exclude ".DS_Store" \
  -q

echo "│  $(du -sh "$LOVE_FILE" | cut -f1)  →  $LOVE_FILE"
echo "└─ Tamam"
echo ""

# ── 3. Web derlemesi ────────────────────────────────────────────────
echo "┌─ love.js derleniyor (birkaç saniye...)"
rm -rf "$BUILD_DIR"

love.js "$LOVE_FILE" "$BUILD_DIR" \
  --title "$TITLE" \
  --memory $MEMORY

echo "│  Çıktı dosyaları:"
ls -lh "$BUILD_DIR" | grep -v "^total" | awk '{printf "│    %s  %s\n", $5, $9}'
echo "└─ Tamam"
echo ""

# ── 4. Özelleştirilmiş index.html ───────────────────────────────────
if [ -f "${GAME_DIR}/web/index.html" ]; then
  cp "${GAME_DIR}/web/index.html" "${BUILD_DIR}/index.html"
  echo "✓  Özelleştirilmiş index.html kopyalandı"
fi

# ── 5. Ek web varlıkları ────────────────────────────────────────────
if [ -d "${GAME_DIR}/web/assets" ]; then
  cp -r "${GAME_DIR}/web/assets/"* "${BUILD_DIR}/"
  echo "✓  Web varlıkları kopyalandı"
fi

# ── 6. Servis ───────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✓  Derleme tamamlandı: $BUILD_DIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if $SERVE; then
  PORT=8080
  echo ""
  echo "  Yerel sunucu başlatılıyor..."
  echo "  → http://localhost:$PORT"
  echo "  (Durdurmak için Ctrl+C)"
  echo ""

  if $OPEN; then
    sleep 1 && (xdg-open "http://localhost:$PORT" 2>/dev/null || open "http://localhost:$PORT" 2>/dev/null) &
  fi

  cd "$BUILD_DIR"

  # Python 3 → Node → fallback
  if command -v python3 &> /dev/null; then
    python3 -m http.server $PORT
  elif command -v node &> /dev/null; then
    node -e "
      const http = require('http');
      const fs   = require('fs');
      const path = require('path');
      const mime = {
        '.html':'text/html','.js':'application/javascript',
        '.wasm':'application/wasm','.data':'application/octet-stream',
        '.css':'text/css','.png':'image/png','.svg':'image/svg+xml'
      };
      http.createServer((req,res)=>{
        var fp = path.join('$BUILD_DIR', req.url === '/' ? '/index.html' : req.url);
        if(!fs.existsSync(fp)){res.writeHead(404);res.end();return;}
        var ext = path.extname(fp);
        res.setHeader('Content-Type', mime[ext]||'application/octet-stream');
        res.setHeader('Cross-Origin-Opener-Policy','same-origin');
        res.setHeader('Cross-Origin-Embedder-Policy','require-corp');
        fs.createReadStream(fp).pipe(res);
      }).listen($PORT, ()=>console.log('Listening on :$PORT'));
    "
  else
    echo "  UYARI: Python3 veya Node bulunamadı — sunucu başlatılamadı."
    echo "  build_web/ klasörünü bir HTTP sunucusunda manuel servis edin."
  fi
fi
