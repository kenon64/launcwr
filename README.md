# WOSERGAME Launcher

Лаунчер приватного сервера **WOSERGAME.NET** (World of Warcraft 3.3.5a) на **Electron + React + TypeScript**.

Живой параллакс-фон (3 графических слоя + туман + частицы + мерцающие руны), авто-починка `realmlist.wtf`,
проверка целостности клиента по SHA256, автообновление клиента и самого лаунчера, индикатор статуса
realm-сервера, полное логирование и режим «Low Performance» для слабых ПК.

> Лаунчер не аффилирован с Blizzard Entertainment. World of Warcraft — торговая марка Blizzard Entertainment Inc.

---

## Возможности

| Группа | Что умеет |
|---|---|
| MVP | Выбор/сохранение пути к клиенту, валидация (Wow.exe, Data, MPQ, локаль), авто-правка `realmlist.wtf` во всех локалях (UTF-8/UTF-16, бэкап `.bak`), запуск `Wow.exe` с аргументами, логирование в файл |
| Запуск | Авто-починка realmlist перед стартом, аргументы `-window`/`-console` + произвольные, UAC-elevation для read-only каталогов, сворачивание при старте игры, single-instance |
| Целостность | SHA256-проверка файлов по `manifest.json` в 4 worker-потока (не блокирует UI), отчёт с классификацией проблем |
| Обновления клиента | Загрузка манифеста (только HTTPS), докачка `.wpart`, проверка SHA256+размера, атомарная замена, контрольная перепроверка |
| Самообновление | Манифест версии → загрузка установщика → обязательная проверка SHA256 → тихая установка NSIS `/S` |
| Статус сервера | TCP-handshake на `play.wosergame.net:3724` + latency, опциональный счётчик игроков через HTTPS `statusUrl`, опрос раз в 60 с |
| Визуал | Параллакс по мыши + синусоидальный дрейф, туман (canvas 0.5×), искры/снег/пепел (object pool), руны (CSS), FPS-кап 20/30/60, авто-даунгрейд качества, полная остановка рендера в свёрнутом окне |
| Безопасность | `contextIsolation` + `sandbox`, whitelist IPC, только HTTPS, защита от path traversal, SHA256 для всех загрузок, без токенов в бандле |
| UX | RU/EN, тёмная/светлая тема, тосты, модалки, плавные переходы вкладок, кастомный titlebar |

## Требования

- **Сборка:** Node.js **20+**, npm 10+ (Windows / Linux / macOS)
- **Запуск:** Windows 10/11 x64 (основная платформа), Linux (AppImage/deb), macOS (dmg)
- Платных зависимостей нет.

## Быстрый старт (разработка)

```bash
npm install
npm run dev          # hot-reload: main + preload + renderer
```

## Сборка дистрибутивов

```bash
# Windows: portable-EXE (автоматический fallback на portable-ZIP при нехватке RAM)
build.bat

# Linux / macOS
./build.sh
```

Артефакты в каталоге `release/`:
- `WOSERGAME-Launcher-1.0.0-Portable.exe` — portable single-file (машины с ≥2 ГБ свободной RAM);
- `WOSERGAME-Launcher-1.0.0-Portable.zip` — portable-архив (fallback для сред с ≤1.5 ГБ RAM:
  распаковал → `WOSERGAME Launcher.exe` в корне).

Скрипты сборки сами прогоняют `typecheck` и тесты перед пакетированием.

### Компиляция в исполняемый файл вручную

```bash
npm ci
npm run icon             # packaging/icon.ico из resources/icon.png (если меняли арт)
npm run build            # бандлы main/preload/renderer → out/

# Обычная машина (≥2 ГБ свободной RAM): portable single-file exe
npx electron-builder --win

# Слабая машина / CI с жёстким лимитом RAM (проверено на 1 ГБ):
npx electron-builder --win --dir --config.win.signAndEditExecutable=false
node scripts/make-portable-zip.mjs     # 7za стартует из лёгкого процесса
```

Готовые npm-команды: `npm run dist:win` (обычная) и `npm run dist:win:lowram` (1 ГБ).

## Тесты и проверки

```bash
npm run typecheck   # строгая типизация main + renderer
npm test            # unit-тесты: realmlist, safeJoin(traversal), config/manifest sanitizer'ы, semver
```

## Структура каталогов пользователя

```
%APPDATA%/WOSERGAME/
├── launcher-config.json     # настройки игрока (атомарная запись, миграции)
├── logs/launcher.log        # журнал (ротация 5 МБ)
└── updates/                 # загруженные установщики лаунчера
```

## Использование

1. Запустите лаунчер → вкладка **«Игра»** → **«Выбрать…»** (или «Найти автоматически») укажите каталог клиента 3.3.5a.
2. Лаунчер проверит клиент и сам пропишет `set realmlist play.wosergame.net` (кнопка «Применить realmlist» — принудительно).
3. Нажмите **ИГРАТЬ**. При read-only каталоге (например, `C:\Program Files`) будет запрошен UAC.
4. **«Настройки»**: язык, тема, качество эффектов (вплоть до полного отключения), частицы, FPS-кап, аргументы запуска, обновления.
5. **«Диагностика»**: статус realm, SHA256-проверка файлов с прогрессом, живой журнал, сведения о системе.

## Адаптация под свой сервер

Вся серверная спецификация живёт в одном файле — [`config/launcher.config.json`](config/launcher.config.json).
Подробный гайд: **[CONFIG_GUIDE.md](CONFIG_GUIDE.md)**. Архитектура и точки расширения: **[ARCHITECTURE.md](ARCHITECTURE.md)**.

## Лицензия

MIT. Арт-ассеты в `src/renderer/src/assets` сгенерированы нейросетью для этого проекта.
