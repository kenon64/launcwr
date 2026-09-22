# CONFIG_GUIDE — адаптация лаунчера под другой сервер

Вся **серверная** часть конфигурации лежит в одном JSON-файле и не требует пересборки кода:

```
config/launcher.config.json      ← правит админ сервера (попадает в resources установщика)
```

Пользовательские настройки (путь к клиенту, язык, графика) хранятся отдельно и не пересекаются:

```
%APPDATA%/WOSERGAME/launcher-config.json   ← создаётся лаунчером сам
```

При старте слои сливаются: серверный файл задаёт рамки и дефолты, пользовательский — только то,
что разрешил сервер. Любое битое поле откатывается к дефолту (sanitizer'ы в `src/main/services/config/schema.ts`).

---

## Полная схема `config/launcher.config.json`

```jsonc
{
  "version": 1,                          // версия схемы (для будущих миграций)
  "server": {
    "name": "WOSERGAME.NET",             // имя в titlebar и hero-блоке (≤64 символов)
    "tagline": "Легендарный приватный сервер...",  // подзаголовок (≤128)
    "clientVersion": "3.3.5a",           // информирует игрока
    "expectedBuild": 12340,              // ожидаемый билд клиента (3.3.5a = 12340)
    "realmHost": "play.wosergame.net",   // КУДА пишется set realmlist (host без порта!)
    "realmPort": 3724,                   // auth-порт для индикатора статуса (TCP-handshake)
    "websiteUrl": "https://wosergame.net",   // только HTTPS или null
    "supportUrl": "https://vk.ru/wosergame", // только HTTPS или null
    "statusUrl": null                    // опционально: HTTPS JSON {"players": N} для счётчика онлайна
  },
  "updates": {
    "enabled": false,                    // автообновление КЛИЕНТА по manifest.json
    "manifestUrl": null,                 // HTTPS-URL manifest.json клиента (см. ниже)
    "channel": "stable"                  // метка канала (для вашей CDN-логики)
  },
  "launcherUpdate": {
    "enabled": false,                    // самообновление лаунчера
    "manifestUrl": null                  // HTTPS-URL манифеста установщика (см. ниже)
  },
  "ui": {
    "defaultLocale": "ru",               // ru | en
    "theme": "dark"                      // dark | light
  },
  "graphics": {
    "quality": "auto",                   // auto | high | medium | low | off  (дефолт для игрока)
    "particles": "embers"                // embers | snow | ash | mixed
  },
  "launch": {
    "extraArgs": [],                     // аргументы Wow.exe по умолчанию (массив строк)
    "autoFixRealmlist": true,            // править realmlist.wtf перед каждым запуском
    "elevateIfReadonly": true,           // UAC-запуск, если каталог клиента read-only
    "minimizeOnGameStart": true          // сворачивать окно лаунчера при старте игры
  }
}
```

### Правила валидации (важно знать админу)

- Любой URL принимается **только с `https://`**; `http://` и URL с логином/паролем отбрасываются в `null`.
- `realmHost` очищается от всего, кроме `[a-z0-9.-]`, и приводится к нижнему регистру.
- `realmPort` клампится в `1..65535`.
- Если файл отсутствует или битый — лаунчер стартует на встроенном fallback (те же значения WOSERGAME).

---

## Включение автообновления клиента

1. Соберите `manifest.json` (пример: [`manifests/client-manifest.example.json`](manifests/client-manifest.example.json)):

```jsonc
{
  "version": 3,                                   // растёт с каждым патчем
  "baseUrl": "https://cdn.wosergame.net/patch/",  // префикс загрузки (HTTPS)
  "files": [
    { "path": "Data/common.MPQ",                   // POSIX-путь от корня клиента; ".." и абсолютные ЗАПРЕЩЕНЫ
      "sha256": "<64 hex>",                        // обязателен, иначе запись игнорируется
      "size": 123456789 }                          // обязателен (для прогресса и сверки)
  ]
}
```

2. Посчитайте хеши файлов клиента:

```bash
# Linux/macOS
find Data -type f -exec sha256sum {} \; > sums.txt
# Windows (PowerShell)
Get-ChildItem -Recurse -File Data | Get-FileHash -Algorithm SHA256
```

3. Выложите файлы на CDN по путям `baseUrl + path`, а манифест — по HTTPS-URL.
4. В конфиге: `"updates": { "enabled": true, "manifestUrl": "https://cdn.wosergame.net/patch/manifest.json" }`.

Поведение лаунчера: при старте обновления скачивается манифест → SHA256-проверка наличия/целостности →
докачиваются **только** проблемные файлы (`.wpart` + Range-resume) → каждый сверяется по SHA256 и размеру →
атомарный `rename` → контрольная перепроверка. Ошибка любого файла после 3 попыток = понятная ошибка в UI.

**Офлайн-альтернатива:** положите манифест в `manifests/client-manifest.json` репозитория — он попадёт в
`resources/manifests/` и будет использован для локальной проверки целостности (вкладка «Диагностика»),
даже если `updates.enabled = false`.

## Включение самообновления лаунчера

Манифест (пример: [`manifests/launcher-update.example.json`](manifests/launcher-update.example.json)):

```jsonc
{
  "version": "1.0.1",                    // semver; сравнение с app.getVersion()
  "url": "https://cdn.../Setup-1.0.1.exe",  // HTTPS, установщик NSIS
  "sha256": "<64 hex>",                  // БЕЗ совпадения установка НЕ запустится
  "size": 88123456,
  "notes": "Текст changelog (≤2000 символов)"
}
```

В конфиге: `"launcherUpdate": { "enabled": true, "manifestUrl": "https://.../launcher-manifest.json" }`.
Лаунчер скачает установщик в `%APPDATA%/WOSERGAME/updates/`, проверит хеш и запустит `Setup.exe /S`,
затем завершится. На Linux/macOS — откроет сайт сервера.

## Индикатор онлайна игроков (опционально)

Если ваш сайт отдаёт JSON вида `{"players": 123}` по HTTPS — укажите его в `server.statusUrl`.
Ответ без числа или с ошибкой просто скрывает счётчик (статус онлайн/офлайн при этом остаётся
честным: он берётся из TCP-подключения к `realmPort`).

## Свои фоновые арты

Слои фона лежат в `src/renderer/src/assets/{far,mid,near}.jpg` (широкие, привязаны к низу кадра):
- `far` — дальний план (небо/горы), маска не применяется;
- `mid` — средний план (силуэты), виден через CSS-маску нижней полосы;
- `near` — передний план (рамка-силуэт), маска ещё ниже.

Замените файлы своими (рекомендуется 1920×~1150, JPEG q85) и выполните `npm run build`.
Исходники генерации и скрипт оптимизации: `art/` + `scripts/optimize-art.mjs` (devDependency `jimp`).

## Брендирование

- Имя/слоган — поля `server.name` / `server.tagline`.
- Иконка приложения — `packaging/icon.ico` (генерируется из `resources/icon.png` командой `npm run icon`; уже лежит в репозитории).
- Цвета UI — CSS-переменные в `src/renderer/src/styles/tokens.css` (обе темы).
- Имя установщика/ярлыков — секция `build` в `package.json` (`productName`, `nsis.shortcutName`).

## Чек-лист релиза под новый сервер

1. [ ] Правка `config/launcher.config.json` (host, порт, ссылки).
2. [ ] Свой `resources/icon.png`.
3. [ ] (опц.) manifest.json клиента на HTTPS-CDN + `updates.enabled`.
4. [ ] (опц.) манифест лаунчера + `launcherUpdate.enabled`.
5. [ ] `build.bat` (в корне) → проверьте артефакт в `release/` (Portable.exe или Portable.zip) на чистой машине/ВМ.
6. [ ] Прогоните `npm test` и `npm run typecheck` (CI-готово из коробки).
