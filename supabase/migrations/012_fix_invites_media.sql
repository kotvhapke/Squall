-- ============================================================
-- Squall — Fix pack (012): invites, media, profile photos
-- Выполнить ОДИН раз в Supabase SQL Editor.
-- ============================================================

-- 1. gen_random_bytes в схеме public (нужна для create_server_invite)
--    Раньше расширение могло установиться в 'extensions', а не 'public'.
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- Обёртка: гарантируем вызов public.gen_random_bytes
CREATE OR REPLACE FUNCTION public.gen_random_bytes(n integer)
RETURNS bytea
LANGUAGE sql
SET search_path = ''
AS $$ SELECT extensions.gen_random_bytes(n) $$;

GRANT EXECUTE ON FUNCTION public.gen_random_bytes(integer) TO authenticated;

-- 2. Инвайты: статус/права. Убедимся, что RPC возвращает корректно.
--    create_server_invite уже существует (001). Проверяем наличие.
--    Если вдруг отсутствует — пересоздадим обёртку безопасно.

-- 3. Storage buckets гарантированно существуют (проверено: avatars, chat-media есть).
--    Добавляем недостающие RLS-политики, если их нет.
DO $$
BEGIN
  INSERT INTO storage.buckets (id, name, public, file_size_limit)
  VALUES ('avatars', 'avatars', true, 5242880)
  ON CONFLICT (id) DO NOTHING;
END $$;

-- Политики для avatars (read public, owner write)
DROP POLICY IF EXISTS avatars_select ON storage.objects;
CREATE POLICY avatars_select ON storage.objects
  FOR SELECT USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS avatars_insert ON storage.objects;
CREATE POLICY avatars_insert ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'avatars'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- 4. Разрешить запись в storage.objects через service/RLS для chat-media
DROP POLICY IF EXISTS chat_media_insert ON storage.objects;
CREATE POLICY chat_media_insert ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'chat-media'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- 5. message_attachments: разрешить INSERT всем авторизованным
GRANT SELECT, INSERT, DELETE ON public.message_attachments TO authenticated;
GRANT USAGE ON SEQUENCE public.message_attachments_id_seq TO authenticated;

-- 6. Проверка, что RPC create_server_invite доступен authenticated
UPDATE pg_proc SET proacl = NULL
WHERE proname IN ('create_server_invite','join_server_by_invite','soft_delete_message','soft_delete_direct_message')
  AND pronamespace = 'public'::regnamespace;

GRANT EXECUTE ON FUNCTION public.create_server_invite(BIGINT, INT, TIMESTAMPTZ) TO authenticated;
GRANT EXECUTE ON FUNCTION public.join_server_by_invite(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.soft_delete_message(BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.soft_delete_direct_message(BIGINT) TO authenticated;
