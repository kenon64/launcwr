@echo off
REM ═════════════════════════════════════════════════════════════════════════
REM  WOSERGAME Launcher — скрипт сборки (Windows)
REM  Требования: Node.js 20+, npm 10+
REM
REM  Основной путь  : portable-EXE (single file) через electron-builder.
REM  Резервный путь : если сборщик упёрся в нехватку RAM (spawn ENOMEM,
REM                   машины/CI с ≤1.5 ГБ) — автоматически собирается
REM                   portable-ZIP: те же файлы, exe в корне архива.
REM  Результат      : release\WOSERGAME-Launcher-<ver>-Portable.exe
REM                   release\WOSERGAME-Launcher-<ver>-Portable.zip (fallback)
REM ═════════════════════════════════════════════════════════════════════════
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo [1/4] Проверка Node.js...
where node >nul 2>nul || (echo ERROR: Node.js не найден в PATH & exit /b 1)
for /f "tokens=1 delims=v" %%i in ('node -p "process.versions.node.split('.')[0]"') do set NODE_MAJOR=%%i
if %NODE_MAJOR% LSS 20 (echo ERROR: нужен Node.js 20+ & exit /b 1)

echo [2/4] Установка зависимостей...
call npm ci --no-audit --no-fund || call npm install --no-audit --no-fund || exit /b 1

echo [3/4] Проверка типов и тесты...
call npm run typecheck || exit /b 1
call npm test || exit /b 1

echo [4/4] Сборка бандлов...
call npm run build || exit /b 1

echo.
echo === Попытка 1: portable EXE (нужно ~2 ГБ свободной RAM) ===
call npx electron-builder --win
if not errorlevel 1 goto :done

echo.
echo === Попытка 2: low-RAM portable ZIP (работает даже с 1 ГБ RAM) ===
call npx electron-builder --win --dir --config.win.signAndEditExecutable=false || exit /b 1
call node scripts/make-portable-zip.mjs || exit /b 1

:done
echo.
echo ГОТОВО. Артефакты:
dir /b release\*Portable*.exe release\*Portable*.zip 2>nul
endlocal
