-- ============================================================
-- Squall — Media & Attachments (004)
-- ============================================================
-- Выполнить после 003_friends.sql
-- ============================================================

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 1. BUCKETS
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('avatars', 'avatars', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('chat-media', 'chat-media', false, 10485760, ARRAY[
  'image/jpeg', 'image/png', 'image/webp', 'image/gif',
  'application/pdf', 'text/plain', 'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-excel',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'application/vnd.ms-powerpoint',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'application/zip'
])
ON CONFLICT (id) DO NOTHING;

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 2. MESSAGE ATTACHMENTS TABLE (must exist before storage RLS)
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

CREATE TABLE IF NOT EXISTS public.message_attachments (
  id                 BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  message_id         BIGINT REFERENCES public.messages(id) ON DELETE CASCADE,
  direct_message_id  BIGINT REFERENCES public.direct_messages(id) ON DELETE CASCADE,
  file_name          TEXT NOT NULL,
  mime_type          TEXT NOT NULL,
  file_size          INT NOT NULL CHECK (file_size > 0 AND file_size <= 10485760),
  storage_path       TEXT NOT NULL,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (
    (message_id IS NOT NULL AND direct_message_id IS NULL) OR
    (message_id IS NULL AND direct_message_id IS NOT NULL)
  )
);

CREATE INDEX IF NOT EXISTS idx_message_attachments_msg ON public.message_attachments(message_id);
CREATE INDEX IF NOT EXISTS idx_message_attachments_dm ON public.message_attachments(direct_message_id);

ALTER TABLE public.message_attachments ENABLE ROW LEVEL SECURITY;

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 3. STORAGE RLS — avatars (public read, owner write)
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

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

DROP POLICY IF EXISTS avatars_update ON storage.objects;
CREATE POLICY avatars_update ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS avatars_delete ON storage.objects;
CREATE POLICY avatars_delete ON storage.objects
  FOR DELETE USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 4. STORAGE RLS — chat-media (references message_attachments)
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

DROP POLICY IF EXISTS chat_media_select ON storage.objects;
CREATE POLICY chat_media_select ON storage.objects
  FOR SELECT USING (
    bucket_id = 'chat-media'
    AND auth.role() = 'authenticated'
    AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR
      EXISTS (
        SELECT 1 FROM public.message_attachments ma
        WHERE ma.storage_path = storage.objects.name
          AND (
            (ma.message_id IS NOT NULL AND EXISTS (
              SELECT 1 FROM public.channels c
              JOIN public.server_members sm ON sm.server_id = c.server_id
              WHERE c.id = (SELECT channel_id FROM public.messages WHERE id = ma.message_id)
                AND sm.user_id = auth.uid()
            ))
            OR
            (ma.direct_message_id IS NOT NULL AND EXISTS (
              SELECT 1 FROM public.direct_conversation_members dcm
              WHERE dcm.conversation_id = (SELECT conversation_id FROM public.direct_messages WHERE id = ma.direct_message_id)
                AND dcm.user_id = auth.uid()
            ))
          )
      )
    )
  );

DROP POLICY IF EXISTS chat_media_insert ON storage.objects;
CREATE POLICY chat_media_insert ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'chat-media'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS chat_media_delete ON storage.objects;
CREATE POLICY chat_media_delete ON storage.objects
  FOR DELETE USING (
    bucket_id = 'chat-media'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 5. RLS — message_attachments
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

DROP POLICY IF EXISTS msg_attachments_select ON public.message_attachments;
CREATE POLICY msg_attachments_select ON public.message_attachments
  FOR SELECT USING (
    (message_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.channels c
      JOIN public.server_members sm ON sm.server_id = c.server_id
      WHERE c.id = (SELECT channel_id FROM public.messages WHERE id = message_id)
        AND sm.user_id = auth.uid()
    ))
    OR
    (direct_message_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.direct_conversation_members dcm
      WHERE dcm.conversation_id = (SELECT conversation_id FROM public.direct_messages WHERE id = direct_message_id)
        AND dcm.user_id = auth.uid()
    ))
  );

DROP POLICY IF EXISTS msg_attachments_insert ON public.message_attachments;
CREATE POLICY msg_attachments_insert ON public.message_attachments
  FOR INSERT WITH CHECK (true);

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 6. GRANTS
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

GRANT SELECT, INSERT, DELETE ON public.message_attachments TO authenticated;
GRANT USAGE ON SEQUENCE public.message_attachments_id_seq TO authenticated;