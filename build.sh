#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
#  WOSERGAME Launcher — скрипт сборки (Linux/macOS)
#  Требования: Node.js 20+, npm 10+
#
#  Основной путь  : пакет под текущую ОС (Linux: AppImage/deb, mac: dmg).
#  Резервный путь : при нехватке RAM (spawn ENOMEM, ≤1.5 ГБ) — win-unpacked
#                   + portable-ZIP через лёгкий процесс (7za из node-скрипта).
# ═══════════════════════════════════════════════════════════════════════════
set -uo pipefail
cd "$(dirname "$0")"

echo "[1/4] Проверка Node.js..."
command -v node >/dev/null || { echo "ERROR: Node.js не найден"; exit 1; }
NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
[ "$NODE_MAJOR" -ge 20 ] || { echo "ERROR: нужен Node.js 20+"; exit 1; }

echo "[2/4] Установка зависимостей..."
npm ci --no-audit --no-fund || npm install --no-audit --no-fund || exit 1

echo "[3/4] Проверка типов и тесты..."
npm run typecheck || exit 1
npm test || exit 1

echo "[4/4] Сборка бандлов..."
npm run build || exit 1

echo
echo "=== Попытка 1: нативный пакет (нужно ~2 ГБ свободной RAM) ==="
if [ "$(uname)" = "Darwin" ]; then
  npx electron-builder --mac
else
  npx electron-builder --linux
fi

if [ $? -ne 0 ]; then
  echo
  echo "=== Попытка 2: low-RAM portable ZIP (работает даже с 1 ГБ RAM) ==="
  npx electron-builder --win --dir --config.win.signAndEditExecutable=false || exit 1
  node scripts/make-portable-zip.mjs || exit 1
fi

echo
echo "ГОТОВО. Артефакты:"
ls -la release/ | grep -Ei 'portable|appimage|deb|dmg' || true
