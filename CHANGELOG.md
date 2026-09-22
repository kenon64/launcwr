# Changelog

Формат: [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/), версионирование — [SemVer](https://semver.org/lang/ru/).

## [1.0.3] — 2026-09-22

### Исправлено
- **Критический дефект упаковки**: негатив-паттерн `!**/{…,src,…}/**` в `build.files`
  вырезал `node_modules/electron-log/src` из asar → собранный exe падал на старте с
  `Cannot find module './src/main'`. Поле `files` сведено к безопасному белому списку
  `["out/**", "!out/**/*.map", "package.json"]` (production-зависимости electron-builder
  добавляет сам). Содержимое asar проверено напрямую: `electron-log/src/main/**` на месте,
  каталогов проекта внутри asar нет.

## [1.0.2] — 2026-09-22

### Исправлено
- **Скрипты сборки и иконка больше не живут в каталоге `build/`**: он исключается из снапшотов
  воркспэйса, из-за чего скачанные копии проекта приходили без `build.bat` и `icon.ico`.
  Теперь: `build.bat` и `build.sh` — в корне проекта, `buildResources` = `packaging/`
  (`packaging/icon.ico`), `win.icon` указывает туда же.
- `scripts/make-ico.mjs` по умолчанию пишет в `packaging/icon.ico`.

## [1.0.1] — 2026-09-22

### Изменено
- Windows-дистрибутив переведён на **portable** (NSIS-установщик убран из конфигурации):
  `"win": { "target": [{ "target": "portable", "arch": ["x64"] }], "signAndEditExecutable": false }`.
- Аудит поля `build.files`: белый список `out/**` (без `.map`) + `package.json`;
  исходники, арт, тесты, docs и dev-зависимости в asar не попадают.
- Новые скрипты: `scripts/make-ico.mjs` (ICO без electron-builder), `scripts/make-portable-zip.mjs`
  (low-RAM упаковка 7za из лёгкого процесса); npm-команды `dist:win:lowram`, `icon`.
- `build/build.bat|sh`: автоматический fallback «portable EXE → portable ZIP» при `spawn ENOMEM`.
- Самообновление лаунчера адаптировано под portable: подмена exe через rename в `.old`
  (cleanup `.old` при старте) вместо тихой NSIS-установки; `/S` остался только для Setup-имён.

### Проверено
- Low-RAM цепочка прошла end-to-end в среде с лимитом 1 ГБ RAM:
  `release/WOSERGAME-Launcher-1.0.0-Portable.zip` (114 МБ, exe в корне).

## [1.0.0] — 2026-09-22

### Добавлено
- Ядро MVP: выбор/валидация клиента 3.3.5a, авто-правка `realmlist.wtf` (11 локалей, UTF-8/UTF-16, бэкапы),
  запуск `Wow.exe` с аргументами, UAC-elevation для read-only каталогов.
- Живой фон: 3-слойный параллакс (мышь + синусоидальный дрейф), туман на canvas 0.5×,
  частицы (искры/снег/пепел/микс), мерцающие руны, виньетка; FPS-кап и режимы качества вплоть до «off».
- Проверка целостности SHA256 в пуле worker_threads с прогрессом и отчётом.
- Автообновление клиента по manifest.json (докачка, SHA256+size, атомарная замена, контрольная проверка).
- Самообновление лаунчера (manifest → SHA256 → тихий NSIS `/S`).
- Индикатор статуса realm (TCP 3724, latency, опц. счётчик игроков), опрос 60 с.
- Настройки: RU/EN, тёмная/светлая тема, графика, аргументы запуска, обновления; атомарный JSON-конфиг с миграциями.
- Диагностика: живой лог-вьюер (кольцо 400 записей + файл с ротацией), статус, целостность, система.
- Безопасность: sandbox+contextIsolation, whitelist IPC, HTTPS-only, path traversal fail-close, SHA256 всех загрузок.
- Дистрибутивы: NSIS-установщик + portable (Windows), AppImage/deb (Linux), dmg (macOS); build.bat/build.sh.
- Документация: README, CONFIG_GUIDE, ARCHITECTURE; unit-тесты (33) на node:test.
