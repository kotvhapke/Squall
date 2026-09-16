-- ============================================================
-- Squall — Party Room (014): party_messages, voice room, memberships
-- Выполнить ОДИН раз в Supabase SQL Editor.
-- ============================================================

-- 1. Party messages (mini-chat for each party)
CREATE TABLE IF NOT EXISTS public.party_messages (
  id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  party_id     BIGINT NOT NULL REFERENCES public.party_listings(id) ON DELETE CASCADE,
  author_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  content      TEXT NOT NULL CHECK (char_length(content) BETWEEN 1 AND 4000),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_party_messages_party ON public.party_messages(party_id, created_at ASC);

ALTER TABLE public.party_messages ENABLE ROW LEVEL SECURITY;

-- Members of a party can read/write messages
DROP POLICY IF EXISTS party_messages_select ON public.party_messages;
CREATE POLICY party_messages_select ON public.party_messages
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.party_members WHERE party_id = party_messages.party_id AND user_id = auth.uid())
    OR EXISTS (SELECT 1 FROM public.party_listings WHERE id = party_messages.party_id AND leader_id = auth.uid())
  );

DROP POLICY IF EXISTS party_messages_insert ON public.party_messages;
CREATE POLICY party_messages_insert ON public.party_messages
  FOR INSERT WITH CHECK (
    author_id = auth.uid()
    AND (
      EXISTS (SELECT 1 FROM public.party_members WHERE party_id = party_messages.party_id AND user_id = auth.uid())
      OR EXISTS (SELECT 1 FROM public.party_listings WHERE id = party_messages.party_id AND leader_id = auth.uid())
    )
  );

GRANT SELECT, INSERT ON public.party_messages TO authenticated;
GRANT USAGE ON SEQUENCE public.party_messages_id_seq TO authenticated;

-- 2. Add party_messages to realtime publication
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'party_messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.party_messages;
  END IF;
END $$;

-- 3. RPC: get_my_party_memberships — returns parties where user is leader or member
CREATE OR REPLACE FUNCTION public.get_my_party_memberships()
RETURNS SETOF public.party_listings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  RETURN QUERY
  SELECT pl.*
  FROM public.party_listings pl
  WHERE pl.status NOT IN ('cancelled')
    AND (
      pl.leader_id = auth.uid()
      OR EXISTS (SELECT 1 FROM public.party_members WHERE party_id = pl.id AND user_id = auth.uid())
    )
  ORDER BY pl.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_party_memberships() TO authenticated;

-- 4. RPC: get_party_messages
CREATE OR REPLACE FUNCTION public.get_party_messages(p_party_id BIGINT)
RETURNS TABLE (id BIGINT, party_id BIGINT, author_id UUID, content TEXT, created_at TIMESTAMPTZ,
  author_username TEXT, author_display_name TEXT, author_avatar_url TEXT, author_status TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.party_members WHERE party_id = p_party_id AND user_id = auth.uid()
    UNION ALL
    SELECT 1 FROM public.party_listings WHERE id = p_party_id AND leader_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'not a member of this party';
  END IF;

  RETURN QUERY
  SELECT pm.id, pm.party_id, pm.author_id, pm.content, pm.created_at,
    pr.username, pr.display_name, pr.avatar_url, pr.status
  FROM public.party_messages pm
  JOIN public.profiles pr ON pr.id = pm.author_id
  WHERE pm.party_id = p_party_id
  ORDER BY pm.created_at ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_party_messages(BIGINT) TO authenticated;

-- 5. RPC: send_party_message
CREATE OR REPLACE FUNCTION public.send_party_message(p_party_id BIGINT, p_content TEXT)
RETURNS TABLE (id BIGINT, party_id BIGINT, author_id UUID, content TEXT, created_at TIMESTAMPTZ,
  author_username TEXT, author_display_name TEXT, author_avatar_url TEXT, author_status TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF char_length(p_content) < 1 OR char_length(p_content) > 4000 THEN
    RAISE EXCEPTION 'content must be 1-4000 characters';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.party_members WHERE party_id = p_party_id AND user_id = auth.uid()
    UNION ALL
    SELECT 1 FROM public.party_listings WHERE id = p_party_id AND leader_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'not a member of this party';
  END IF;

  RETURN QUERY
  INSERT INTO public.party_messages (party_id, author_id, content)
  VALUES (p_party_id, auth.uid(), p_content)
  RETURNING id, party_id, author_id, content, created_at,
    (SELECT username FROM public.profiles WHERE id = auth.uid()),
    (SELECT display_name FROM public.profiles WHERE id = auth.uid()),
    (SELECT avatar_url FROM public.profiles WHERE id = auth.uid()),
    (SELECT status FROM public.profiles WHERE id = auth.uid());
END;
$$;

GRANT EXECUTE ON FUNCTION public.send_party_message(BIGINT, TEXT) TO authenticated;

-- 6. RPC: get_party_members_with_profiles
CREATE OR REPLACE FUNCTION public.get_party_members_with_profiles(p_party_id BIGINT)
RETURNS TABLE (user_id UUID, username TEXT, display_name TEXT, avatar_url TEXT, status TEXT, joined_at TIMESTAMPTZ)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  RETURN QUERY
  SELECT u.id, p.username, p.display_name, p.avatar_url, p.status, pm.joined_at
  FROM public.party_members pm
  JOIN public.profiles p ON p.id = pm.user_id
  JOIN public.party_listings pl ON pl.id = pm.party_id
  LEFT JOIN public.profiles leader ON leader.id = pl.leader_id
  WHERE pm.party_id = p_party_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_party_members_with_profiles(BIGINT) TO authenticated;

-- 7. Expand call_sessions CHECK to allow party calls (all 3 null)
ALTER TABLE public.calls DROP CONSTRAINT IF EXISTS calls_check CASCADE;
ALTER TABLE public.calls ADD CONSTRAINT calls_check CHECK (
  (server_id IS NOT NULL AND channel_id IS NOT NULL AND conversation_id IS NULL) OR
  (server_id IS NULL AND channel_id IS NULL AND conversation_id IS NOT NULL) OR
  (server_id IS NULL AND channel_id IS NULL AND conversation_id IS NULL)
);

-- Also fix call_sessions (006) if it exists
ALTER TABLE public.call_sessions DROP CONSTRAINT IF EXISTS call_sessions_check CASCADE;
ALTER TABLE public.call_sessions ADD CONSTRAINT call_sessions_check CHECK (
  (server_id IS NOT NULL AND channel_id IS NOT NULL AND conversation_id IS NULL) OR
  (server_id IS NULL AND channel_id IS NULL AND conversation_id IS NOT NULL) OR
  (server_id IS NULL AND channel_id IS NULL AND conversation_id IS NULL)
);

-- 8. Auto-cleanup: parties older than 24h