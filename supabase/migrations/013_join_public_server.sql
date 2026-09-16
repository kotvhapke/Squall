-- ============================================================
-- Squall — Fix pack (013): join public server from Discover
-- Выполнить ОДИН раз в Supabase SQL Editor.
-- ============================================================
-- Discover раньше пытался создать инвайт чужого публичного сервера
-- (create_server_invite доступен только owner/moderator) — это всегда
-- падало с ошибкой. Теперь публичный сервер можно вступить напрямую.

CREATE OR REPLACE FUNCTION public.join_public_server(target_server_id BIGINT)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID;
  v_visibility TEXT;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;

  SELECT visibility INTO v_visibility FROM public.servers WHERE id = target_server_id;
  IF v_visibility IS NULL THEN RAISE EXCEPTION 'server not found'; END IF;
  IF v_visibility <> 'public' THEN RAISE EXCEPTION 'server is not public'; END IF;

  IF EXISTS (SELECT 1 FROM public.server_members WHERE server_id = target_server_id AND user_id = v_uid) THEN
    RAISE EXCEPTION 'already a member of this server';
  END IF;

  INSERT INTO public.server_members (server_id, user_id, role)
  VALUES (target_server_id, v_uid, 'member');

  RETURN target_server_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.join_public_server(BIGINT) TO authenticated;