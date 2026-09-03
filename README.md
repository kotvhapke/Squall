# Squall

Голосовые каналы, видеозвонки, Party Finder — геймерский мессенджер на Flutter, Supabase и LiveKit.

## Быстрый старт (Web)

```bash
# 1. Создай config/supabase.local.json по примеру config/supabase.example.json
# 2. Запусти web-версию
flutter run -d web-server --dart-define-from-file=config/supabase.local.json
```

## Сборка (Web)

```bash
flutter build web --dart-define-from-file=config/supabase.local.json
```

Готовый билд лежит в `build/web/`.

## Запуск (Windows)

```bash
flutter build windows --dart-define-from-file=config/supabase.local.json
```

## Технологии

- **Flutter 3.x** — Dart, Provider
- **Supabase** — Auth (email+password), PostgreSQL, Realtime, Storage
- **LiveKit** — WebRTC голосовые каналы и видеозвонки

## Структура

```
lib/
├── core/          — сервисы, тема, настройки, фича-флаги
├── features/      — экраны (auth, servers, dms, calls, profile, settings, party_finder)
├── shared/        — общие виджеты (avatar, button, panel, states)
supabase/
├── migrations/    — SQL-миграции (001–009)
├── functions/     — Edge Functions (livekit-token)
config/
├── supabase.example.json  — шаблон конфига
├── supabase.local.json    — локальный конфиг (в .gitignore)
```

## Конфигурация

Скопируй `config/supabase.example.json` в `config/supabase.local.json` и заполни:

```json
{
  "SUPABASE_URL": "https://your-project.supabase.co",
  "SUPABASE_ANON_KEY": "your-anon-key",
  "LIVEKIT_URL": "wss://your-livekit-instance.livekit.cloud"
}
```

## Миграции Supabase

Выполнить в SQL Editor по порядку:
1. `supabase/migrations/001_initial_schema.sql`
2. `supabase/migrations/002_social_voice.sql`
3. `supabase/migrations/003_friends.sql`
4. `supabase/migrations/004_media_storage.sql`
5. `supabase/migrations/005_public_servers.sql`
6. `supabase/migrations/006_calls_livekit.sql`
7. `supabase/migrations/007_channel_categories.sql`
8. `supabase/migrations/008_fix_rls.sql`
9. `supabase/migrations/009_party_finder.sql`

## Edge Functions

Развернуть `supabase/functions/livekit-token/` в Supabase Dashboard → Edge Functions → `livekit-token`.

## Лицензия

MIT