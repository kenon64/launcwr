# ARCHITECTURE — как устроен WOSERGAME Launcher

## Слои и потоки данных

```
┌─────────────────────────────── Renderer (Chromium, sandbox) ───────────────────────────────┐
│  React 18 + CSS                                                                              │
│  ├─ ParallaxScene ── SceneController (1×rAF: слои-DOM, 2×fog-canvas, particles-canvas)      │
│  ├─ TitleBar / SideNav / PlayPanel / SettingsPanel / DiagnosticsPanel                      │
│  ├─ AppStateProvider (конфиг, статус, игра, патчи, логи)  ◄── события main                  │
│  └─ window.launcherAPI (contextBridge, whitelist)                                            │
└───────────────▲───────────────────────────────│────────────────────────────────────────────┘
                │ события (event:<name>)        │ ipcRenderer.invoke (каналы из src/shared/ipc.ts)
┌───────────────┴───────────────────────────────▼────────────────────────────────────────────┐
│  Preload: contextBridge.exposeInMainWorld('launcherAPI', …) — только whitelist-каналы       │
└───────────────▲───────────────────────────────│────────────────────────────────────────────┘
                │ webContents.send              │ ipcMain.handle / on
┌───────────────┴───────────────────────────────▼────────────────────────────────────────────┐
│  Main (Node):                                                                                │
│   index.ts → WindowManager → registerIpc → сервисы:                                        │
│    ConfigService · LoggerService · WowClientService · RealmlistService · LaunchService     │
│    IntegrityService (worker_threads ×4) · PatchUpdater · LauncherUpdater                   │
│    RealmStatusService · EventBus                                                            │
│   Утилиты: safePath · hash · download (resume+SHA256) · http (HTTPS-only) · semver          │
└─────────────────────────────────────────────────────────────────────────────────────────────┘
```

## Ключевые решения

### Безопасность
- `contextIsolation: true`, `nodeIntegration: false`, `sandbox: true`; renderer не имеет доступа к Node.
- IPC: единый реестр каналов `src/shared/ipc.ts`; preload whitelist'ит и события (`ALLOWED_EVENTS`).
- Сеть: `util/http.ts` и `util/download.ts` отклоняют всё, кроме HTTPS; лимиты размера и таймауты; без userinfo в URL.
- Файлы: `util/safePath.safeJoin()` — fail-close против `../`, абсолютных, UNC, drive-путей и `\0`
  (все пути из manifest.json проходят через него; тесты `tests/safepath.test.ts`).
- Загрузки: обязательная сверка SHA256+размера **до** переименования в целевой файл (`.wpart` → `rename`);
  несовпадение хеша установщика лаунчера = отказ от установки.
- Секретов в бандле нет: токены/ключи не предусмотрены схемой конфига вовсе.

### Конфигурация
- Двухслойность: серверный read-only `resources/config/launcher.config.json` + пользовательский
  `%APPDATA%/WOSERGAME/launcher-config.json`.
- Sanitizer'ы (`services/config/schema.ts`) — чистые функции: любой мусор/инъекции полей откатываются к дефолту;
  миграции по `version`; атомарная запись (`*.tmp` + `rename`) с debounce 400 мс; бэкап битого файла.

### Realmlist 3.3.5a
- Регистронезависимый поиск `Data/<locale>/realmlist.wtf` по 11 локалям.
- Кодировки: UTF-8, UTF-8 BOM, UTF-16LE (BOM) — сохраняются при перезаписи.
- `realmlistCore.ts` — чистый парсер/билдер (unit-тесты): замена/добавление `set realmlist`,
  схлопывание дубликатов, сохранение комментариев и `set patchlist`.
- Бэкап `realmlist.wtf.bak` перед каждой правкой.

### Запуск игры
- `spawn(Wow.exe, args, { cwd, detached })` + `unref()`; событие выхода → `game:state`.
- Read-only каталог + Windows + `elevateIfReadonly` → `powershell Start-Process -Verb RunAs`,
  статус игры затем отслеживается опросом `tasklist /FI "IMAGENAME eq Wow.exe"` (5 с).
- Аргументы: `-window`, `-console` + произвольные из настроек (построчная санитизация).

### Целостность и обновления
- Хеширование — пул до 4 `worker_threads` (worker создаётся из строки кода, без отдельных бандлов),
  прогресс по байтам агрегируется и шлётся событием не чаще ~8 Гц.
- PatchUpdater: manifest → IntegrityService → очередь проблемных файлов → concurrent=2 загрузки с
  resume → SHA256/size → rename → контрольная перепроверка. Отмена = AbortController + teardown пула.

### Визуал и производительность
- **Один** `requestAnimationFrame`-цикл (`SceneController`) на всё: DOM-слои (`transform: translate3d`,
  GPU-композитинг), 2 canvas тумана (рендер в 0.5× разрешения — апскейл даёт мягкость бесплатно),
  1 canvas частиц (object pool, предрендер-спрайты свечения, без `shadowBlur`).
- FPS-кап 20/30/60 через аккумулятор времени; пресеты качества low/medium/high/off.
- Авто-даунгрейд в режиме `auto`: скользящее среднее frame-time > 1.4× интервала → ступень вниз + тост.
- Пауза рендера: `visibilitychange` + событие сворачивания окна (`app:visibility`).
- Руны и прогресс-бар — чисто CSS-анимации (`opacity`/`transform`), JS не тратят.
- `prefers-reduced-motion` уважается.

### Логирование
- `electron-log`: файл `%APPDATA%/WOSERGAME/logs/launcher.log`, ротация 5 МБ.
- Кольцевой буфер 400 записей + IPC-поток `log:entry` → живой лог-вьюер во вкладке «Диагностика».

## Точки расширения

| Хочу… | Где править |
|---|---|
| Добавить вкладку | `App.tsx` (tabs) + новый компонент-панель |
| Новый источник статуса/онлайна | `RealmStatusService.fetchPlayers` / новый адаптер |
| Другой формат манифеста | `updater/manifestSchema.ts` + тесты |
| Новый язык UI | `i18n/strings.ts` (словарь) + `LOCALES` в `shared/validate.ts` |
| Свои арты/маски слоёв | `assets/*.jpg` + `styles/scene.css` (маски) |
| Новая настройка | `shared/types.ts` → `schema.ts` (sanitizer) → SettingsPanel |

## Тестирование

- `npm test` — node:test по скомпилированным чистым модулям (realmlist, safePath, schema, manifestSchema, semver).
- `npm run typecheck` — strict TS для main и renderer отдельно.
- `WOS_SMOKE=1` — smoke-режим main-процесса: после загрузки окна делает `capturePage()` в `smoke.png` и выходит
  (удобно в CI с xvfb: `xvfb-run -a npm run dev` или против собранного `out/`).

## Сборка в средах с дефицитом RAM (spawn ENOMEM)

electron-builder на этапе артифактов спавнит внешние бинари (app-builder для иконки/rcedit,
7za/makensis для упаковки) из уже «тяжёлого» node-процесса (~0.5 ГБ RSS после распаковки Electron).
При cgroup-лимите ≤1 ГБ fork падает с `spawn ENOMEM`. Обход (проверено на 1 ГБ):

1. `--dir` + `signAndEditExecutable:false` — убирает все spawn'ы из тяжёлого процесса
   (asar-integrity выполняется in-process); получается `release/win-unpacked`;
2. `scripts/make-portable-zip.mjs` — пакует 7za **из лёгкого node-процесса** (~30 МБ RSS),
   fork дёшев и лимит не затрагивается; на выходе portable-ZIP с exe в корне.

Команды: `npm run dist:win:lowram` (или fallback внутри `build.bat|sh`).
На машинах с ≥2 ГБ свободной RAM работает обычный `npm run dist:win` (portable single-file exe
с иконкой и version-info; иконка берётся из `packaging/icon.ico`, генерация — `npm run icon`).

## Известные ограничения

- Реальный запуск `Wow.exe` и UAC проверяются только на Windows (в CI-контейнере без дисплея — smoke через xvfb).
- elevated-режим не даёт PID процесса (ограничение `Start-Process -Verb RunAs`), статус берётся из `tasklist`.
- macOS-сборка требует запуска electron-builder на macOS (требование Apple для подписи/нотариации опционально).
