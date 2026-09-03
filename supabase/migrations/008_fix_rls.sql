-- ============================================================
-- Squall — Fix RLS recursion (008 v2)
-- ============================================================
-- Выполнить ПОСЛЕ 008_fix_rls.sql (перезаписывает его политики)
-- Рекурсия: calls_select → call_participants → calls
-- Исправление: calls_select не проверяет call_participants;
-- call_participants_select проверяет user_id ИЛИ server_members напрямую.
-- ============================================================

-- 1. Helper: участник сервера (без RLS)
DROP FUNCTION IF EXISTS public.chk_server_member(BIGINT) CASCADE;
CREATE FUNCTION public.chk_server_member(srv_id BIGINT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.server_members
    WHERE server_id = srv_id AND user_id = auth.uid()
  );
END;
$$;

-- 2. Helper: участник DM
DROP FUNCTION IF EXISTS public.chk_dm_member(BIGINT) CASCADE;
CREATE FUNCTION public.chk_dm_member(conv_id BIGINT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.direct_conversation_members
    WHERE conversation_id = conv_id AND user_id = auth.uid()
  );
END;
$$;

-- 3. Grants for helpers
GRANT EXECUTE ON FUNCTION public.chk_server_member(BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chk_dm_member(BIGINT) TO authenticated;

-- 4. calls — только server_members/DM, никаких call_participants
DROP POLICY IF EXISTS calls_select ON public.calls;
CREATE POLICY calls_select ON public.calls
  FOR SELECT USING (
    (server_id IS NOT NULL AND public.chk_server_member(server_id))
    OR
    (conversation_id IS NOT NULL AND public.chk_dm_member(conversation_id))
  );

DROP POLICY IF EXISTS calls_insert ON public.calls;
CREATE POLICY calls_insert ON public.calls
  FOR INSERT WITH CHECK (
    (server_id IS NOT NULL AND channel_id IS NOT NULL AND public.chk_server_member(server_id))
    OR
    (conversation_id IS NOT NULL AND public.chk_dm_member(conversation_id))
  );

DROP POLICY IF EXISTS calls_update ON public.calls;
CREATE POLICY calls_update ON public.calls
  FOR UPDATE USING (
    (server_id IS NOT NULL AND public.chk_server_member(server_id))
    OR
    (conversation_id IS NOT NULL AND public.chk_dm_member(conversation_id))
  ) WITH CHECK (true);

-- 5. call_participants — проверка себя ИЛИ напрямую server_members/DM, без рекурсии
DROP POLICY IF EXISTS call_participants_select ON public.call_participants;
CREATE POLICY call_participants_select ON public.call_participants
  FOR SELECT USING (
    user_id = auth.uid()
    OR
    EXISTS (
      SELECT 1 FROM public.calls c
      WHERE c.id = call_participants.call_id
        AND (
          (c.server_id IS NOT NULL AND public.chk_server_member(c.server_id))
          OR
          (c.conversation_id IS NOT NULL AND public.chk_dm_member(c.conversation_id))
        )
    )
  );

DROP POLICY IF EXISTS call_participants_insert ON public.call_participants;
CREATE POLICY call_participants_insert ON public.call_participants
  FOR INSERT WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM public.calls c
      WHERE c.id = call_id
        AND (
          (c.server_id IS NOT NULL AND public.chk_server_member(c.server_id))
          OR
          (c.conversation_id IS NOT NULL AND public.chk_dm_member(c.conversation_id))
        )
    )
  );

DROP POLICY IF EXISTS call_participants_update ON public.call_participants;
CREATE POLICY call_participants_update ON public.call_participants
  FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- 6. Grants
GRANT SELECT, INSERT, UPDATE ON TABLE public.calls TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.call_participants TO authenticated;
GRANT USAGE ON SEQUENCE public.calls_id_seq TO authenticated;