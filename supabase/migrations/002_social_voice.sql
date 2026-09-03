-- ============================================================
-- Squall — Social & Voice (002)
-- ============================================================
-- Выполнить после 001_initial_schema.sql в Supabase SQL Editor.
-- ============================================================

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 1. FRIEND REQUESTS / PRESENCE
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

CREATE TABLE IF NOT EXISTS public.friend_requests (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  sender_id   UUID NOT NULL,
  receiver_id UUID NOT NULL,
  status      TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','accepted','rejected','cancelled')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ,
  UNIQUE (sender_id, receiver_id)
);

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 2. UNREAD COUNTERS (server + DM)
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

CREATE TABLE IF NOT EXISTS public.unreads (
  user_id         UUID NOT NULL,
  channel_id      BIGINT,
  conversation_id BIGINT,
  last_read_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (
    (channel_id IS NOT NULL AND conversation_id IS NULL) OR
    (channel_id IS NULL AND conversation_id IS NOT NULL)
  ),
  UNIQUE (user_id, channel_id),
  UNIQUE (user_id, conversation_id)
);

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 3. CALL LOGS (for future LiveKit integration)
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

CREATE TABLE IF NOT EXISTS public.calls (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  room_name   TEXT UNIQUE NOT NULL,
  server_id   BIGINT REFERENCES public.servers(id) ON DELETE CASCADE,
  channel_id  BIGINT REFERENCES public.channels(id) ON DELETE CASCADE,
  conversation_id BIGINT REFERENCES public.direct_conversations(id) ON DELETE CASCADE,
  started_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  ended_at    TIMESTAMPTZ,
  CHECK (
    (server_id IS NOT NULL AND channel_id IS NOT NULL AND conversation_id IS NULL) OR
    (server_id IS NULL AND channel_id IS NULL AND conversation_id IS NOT NULL)
  )
);

CREATE TABLE IF NOT EXISTS public.call_participants (
  user_id    UUID NOT NULL,
  call_id    BIGINT NOT NULL REFERENCES public.calls(id) ON DELETE CASCADE,
  joined_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  left_at    TIMESTAMPTZ,
  muted      BOOLEAN NOT NULL DEFAULT false,
  deafened   BOOLEAN NOT NULL DEFAULT false,
  PRIMARY KEY (user_id, call_id)
);

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- INDEXES
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

CREATE INDEX IF NOT EXISTS idx_unreads_user ON public.unreads(user_id);
CREATE INDEX IF NOT EXISTS idx_friend_requests_receiver ON public.friend_requests(receiver_id, status);
CREATE INDEX IF NOT EXISTS idx_calls_room ON public.calls(room_name);
CREATE INDEX IF NOT EXISTS idx_call_participants_call ON public.call_participants(call_id);

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- RLS — ENABLE
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

ALTER TABLE public.friend_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.unreads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.calls ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.call_participants ENABLE ROW LEVEL SECURITY;

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- RLS — POLICIES
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

DROP POLICY IF EXISTS friend_requests_select ON public.friend_requests;
CREATE POLICY friend_requests_select ON public.friend_requests
  FOR SELECT USING (sender_id = auth.uid() OR receiver_id = auth.uid());

DROP POLICY IF EXISTS friend_requests_insert ON public.friend_requests;
CREATE POLICY friend_requests_insert ON public.friend_requests
  FOR INSERT WITH CHECK (sender_id = auth.uid());

DROP POLICY IF EXISTS friend_requests_update ON public.friend_requests;
CREATE POLICY friend_requests_update ON public.friend_requests
  FOR UPDATE USING (receiver_id = auth.uid()) WITH CHECK (receiver_id = auth.uid());

-- Unreads: user sees only their own
DROP POLICY IF EXISTS unreads_select ON public.unreads;
CREATE POLICY unreads_select ON public.unreads
  FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS unreads_upsert ON public.unreads;
CREATE POLICY unreads_upsert ON public.unreads
  FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS unreads_update ON public.unreads;
CREATE POLICY unreads_update ON public.unreads
  FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- Calls: participants can read, any authenticated can create
DROP POLICY IF EXISTS calls_select ON public.calls;
CREATE POLICY calls_select ON public.calls
  FOR SELECT USING (EXISTS (
    SELECT 1 FROM public.call_participants WHERE call_id = calls.id AND user_id = auth.uid()
  ));

DROP POLICY IF EXISTS calls_insert ON public.calls;
CREATE POLICY calls_insert ON public.calls
  FOR INSERT WITH CHECK (true);

-- Call participants: user sees only their own, can insert self
DROP POLICY IF EXISTS call_participants_select ON public.call_participants;
CREATE POLICY call_participants_select ON public.call_participants
  FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS call_participants_insert ON public.call_participants;
CREATE POLICY call_participants_insert ON public.call_participants
  FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS call_participants_update ON public.call_participants;
CREATE POLICY call_participants_update ON public.call_participants
  FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- GRANTS
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

GRANT SELECT, INSERT, UPDATE ON TABLE public.friend_requests TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.unreads TO authenticated;
GRANT SELECT, INSERT ON TABLE public.calls TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.call_participants TO authenticated;

GRANT USAGE ON SEQUENCE public.friend_requests_id_seq TO authenticated;
GRANT USAGE ON SEQUENCE public.calls_id_seq TO authenticated;