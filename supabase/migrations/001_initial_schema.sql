-- ============================================================
-- Squall MVP — Initial Schema
-- ============================================================
-- Выполнить ОДИН раз в Supabase SQL Editor нового проекта.
-- ============================================================

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 0. EXTENSIONS
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 1. SAFE HELPER FUNCTIONS (SECURITY DEFINER)
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

DROP FUNCTION IF EXISTS public.is_server_member(BIGINT) CASCADE;
CREATE FUNCTION public.is_server_member(server_id BIGINT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.server_members
    WHERE server_members.server_id = is_server_member.server_id
      AND server_members.user_id = auth.uid()
  );
END;
$$;

DROP FUNCTION IF EXISTS public.get_server_role(BIGINT) CASCADE;
CREATE FUNCTION public.get_server_role(server_id BIGINT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_role TEXT;
BEGIN
  SELECT role INTO v_role FROM public.server_members
  WHERE server_members.server_id = get_server_role.server_id
    AND server_members.user_id = auth.uid();
  RETURN v_role;
END;
$$;

DROP FUNCTION IF EXISTS public.is_dm_member(BIGINT) CASCADE;
CREATE FUNCTION public.is_dm_member(conversation_id BIGINT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.direct_conversation_members
    WHERE direct_conversation_members.conversation_id = is_dm_member.conversation_id
      AND direct_conversation_members.user_id = auth.uid()
  );
END;
$$;

DROP FUNCTION IF EXISTS public.is_blocked(UUID) CASCADE;
CREATE FUNCTION public.is_blocked(other_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.blocks
    WHERE (blocks.blocker_id = auth.uid() AND blocks.blocked_id = is_blocked.other_user_id)
       OR (blocks.blocker_id = is_blocked.other_user_id AND blocks.blocked_id = auth.uid())
  );
END;
$$;

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 2. TABLES
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

CREATE TABLE IF NOT EXISTS public.profiles (
  id          UUID PRIMARY KEY,
  username    TEXT UNIQUE NOT NULL CHECK (char_length(username) BETWEEN 2 AND 32),
  display_name TEXT NOT NULL DEFAULT '',
  avatar_url  TEXT DEFAULT '',
  status      TEXT NOT NULL DEFAULT 'online' CHECK (status IN ('online','idle','dnd','offline')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.servers (
  id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  owner_id  UUID NOT NULL,
  name      TEXT NOT NULL CHECK (char_length(name) BETWEEN 1 AND 100),
  icon_url  TEXT DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.server_members (
  server_id BIGINT NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
  user_id   UUID NOT NULL,
  role      TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner','moderator','member')),
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (server_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.channels (
  id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  server_id BIGINT NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
  name      TEXT NOT NULL CHECK (char_length(name) BETWEEN 1 AND 100),
  type      TEXT NOT NULL DEFAULT 'text' CHECK (type IN ('text','voice')),
  position  INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.messages (
  id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  channel_id BIGINT NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
  author_id  UUID NOT NULL,
  content    TEXT NOT NULL CHECK (char_length(content) BETWEEN 1 AND 4000),
  reply_to_id BIGINT REFERENCES public.messages(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  edited_at  TIMESTAMPTZ,
  deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.direct_conversations (
  id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.direct_conversation_members (
  conversation_id BIGINT NOT NULL REFERENCES public.direct_conversations(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL,
  PRIMARY KEY (conversation_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.direct_messages (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  conversation_id BIGINT NOT NULL REFERENCES public.direct_conversations(id) ON DELETE CASCADE,
  author_id       UUID NOT NULL,
  content         TEXT NOT NULL CHECK (char_length(content) BETWEEN 1 AND 4000),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  edited_at       TIMESTAMPTZ,
  deleted_at      TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.blocks (
  blocker_id UUID NOT NULL,
  blocked_id UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id),
  CHECK (blocker_id <> blocked_id)
);

CREATE TABLE IF NOT EXISTS public.reports (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  reporter_id UUID NOT NULL,
  target_type TEXT NOT NULL CHECK (target_type IN ('message','profile','server')),
  target_id   TEXT NOT NULL,
  reason      TEXT NOT NULL CHECK (char_length(reason) BETWEEN 1 AND 2000),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- NEW: server_invites
CREATE TABLE IF NOT EXISTS public.server_invites (
  id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  server_id  BIGINT NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
  creator_id UUID NOT NULL,
  code       TEXT UNIQUE NOT NULL CHECK (char_length(code) = 16),
  expires_at TIMESTAMPTZ,
  max_uses   INT NOT NULL DEFAULT 0 CHECK (max_uses >= 0),
  uses       INT NOT NULL DEFAULT 0 CHECK (uses >= 0),
  revoked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 2a. FOREIGN KEYS
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

-- Profiles FK to auth.users
DO $$ BEGIN
  ALTER TABLE public.profiles ADD CONSTRAINT fk_profiles_id
    FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- All other user UUIDs → profiles.id
DO $$ BEGIN
  ALTER TABLE public.servers ADD CONSTRAINT fk_servers_owner
    FOREIGN KEY (owner_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE public.server_members ADD CONSTRAINT fk_server_members_user
    FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE public.messages ADD CONSTRAINT fk_messages_author
    FOREIGN KEY (author_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE public.direct_conversation_members ADD CONSTRAINT fk_dm_members_user
    FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE public.direct_messages ADD CONSTRAINT fk_direct_messages_author
    FOREIGN KEY (author_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE public.blocks ADD CONSTRAINT fk_blocks_blocker
    FOREIGN KEY (blocker_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE public.blocks ADD CONSTRAINT fk_blocks_blocked
    FOREIGN KEY (blocked_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE public.reports ADD CONSTRAINT fk_reports_reporter
    FOREIGN KEY (reporter_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE public.server_invites ADD CONSTRAINT fk_server_invites_creator
    FOREIGN KEY (creator_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 3. INDEXES
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

CREATE INDEX IF NOT EXISTS idx_messages_channel ON public.messages(channel_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_author ON public.messages(author_id);
CREATE INDEX IF NOT EXISTS idx_dm_conversation ON public.direct_messages(conversation_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_server_members_user ON public.server_members(user_id);
CREATE INDEX IF NOT EXISTS idx_server_members_server ON public.server_members(server_id);
CREATE INDEX IF NOT EXISTS idx_channels_server ON public.channels(server_id, position);
CREATE INDEX IF NOT EXISTS idx_blocks_blocked ON public.blocks(blocked_id);
CREATE INDEX IF NOT EXISTS idx_blocks_blocker ON public.blocks(blocker_id);
CREATE INDEX IF NOT EXISTS idx_server_invites_code ON public.server_invites(code);
CREATE INDEX IF NOT EXISTS idx_server_invites_server ON public.server_invites(server_id);

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 4. AUTO-PROFILE ON SIGNUP
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
CREATE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.profiles (id, username, display_name)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', 'user_' || substr(NEW.id::text, 1, 8)),
    COALESCE(NEW.raw_user_meta_data->>'display_name', '')
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 5. UPDATE-EDITED_AT TRIGGERS
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

DROP FUNCTION IF EXISTS public.update_edited_at() CASCADE;
CREATE FUNCTION public.update_edited_at()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  NEW.edited_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS messages_edited_at ON public.messages;
CREATE TRIGGER messages_edited_at
  BEFORE UPDATE OF content ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.update_edited_at();

DROP TRIGGER IF EXISTS direct_messages_edited_at ON public.direct_messages;
CREATE TRIGGER direct_messages_edited_at
  BEFORE UPDATE OF content ON public.direct_messages
  FOR EACH ROW EXECUTE FUNCTION public.update_edited_at();

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 6. RPC: create_server
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

DROP FUNCTION IF EXISTS public.create_server(TEXT, TEXT) CASCADE;
CREATE FUNCTION public.create_server(server_name TEXT, icon_url TEXT DEFAULT '')
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_server_id BIGINT;
  v_uid UUID;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  INSERT INTO public.servers (owner_id, name, icon_url)
  VALUES (v_uid, server_name, icon_url)
  RETURNING id INTO v_server_id;

  INSERT INTO public.server_members (server_id, user_id, role)
  VALUES (v_server_id, v_uid, 'owner');

  RETURN v_server_id;
END;
$$;

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 7. RPC: transfer_server_ownership
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

DROP FUNCTION IF EXISTS public.transfer_server_ownership(BIGINT, UUID) CASCADE;
CREATE FUNCTION public.transfer_server_ownership(
  target_server_id BIGINT,
  new_owner_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID;
  v_old_owner_id UUID;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;

  -- Lock the server row before checking ownership
  PERFORM id FROM public.servers WHERE id = target_server_id FOR UPDATE;

  -- Only current owner can transfer
  IF (SELECT owner_id FROM public.servers WHERE id = target_server_id) IS DISTINCT FROM v_uid THEN
    RAISE EXCEPTION 'only the server owner can transfer ownership';
  END IF;

  -- New owner must be a member
  IF NOT EXISTS (SELECT 1 FROM public.server_members WHERE server_id = target_server_id AND user_id = new_owner_id) THEN
    RAISE EXCEPTION 'new owner must be a server member';
  END IF;

  -- Swap roles: old owner becomes member, new owner becomes owner
  UPDATE public.server_members SET role = 'member'
  WHERE server_id = target_server_id AND user_id = v_uid;

  UPDATE public.server_members SET role = 'owner'
  WHERE server_id = target_server_id AND user_id = new_owner_id;

  -- Update servers.owner_id
  UPDATE public.servers SET owner_id = new_owner_id
  WHERE id = target_server_id;
END;
$$;

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 8. RPC: set_member_role
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

DROP FUNCTION IF EXISTS public.set_member_role(BIGINT, UUID, TEXT) CASCADE;
CREATE FUNCTION public.set_member_role(
  target_server_id BIGINT,
  target_user_id UUID,
  new_role TEXT
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  caller_role TEXT;
BEGIN
  SELECT public.get_server_role(target_server_id) INTO caller_role;
  IF caller_role IS DISTINCT FROM 'owner' THEN
    RAISE EXCEPTION 'only the server owner can manage roles';
  END IF;

  IF new_role NOT IN ('moderator','member') THEN
    RAISE EXCEPTION 'role must be moderator or member; use transfer_server_ownership to assign owner';
  END IF;

  IF target_user_id IN (SELECT user_id FROM public.server_members WHERE server_id = target_server_id AND role = 'owner') THEN
    RAISE EXCEPTION 'use transfer_server_ownership to change the owner role';
  END IF;

  UPDATE public.server_members
  SET role = set_member_role.new_role
  WHERE server_members.server_id = set_member_role.target_server_id
    AND server_members.user_id = set_member_role.target_user_id;
END;
$$;

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 9. RPC: remove_member
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

DROP FUNCTION IF EXISTS public.remove_member(BIGINT, UUID) CASCADE;
CREATE FUNCTION public.remove_member(
  target_server_id BIGINT,
  target_user_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  caller_role TEXT;
  owner_count INT;
BEGIN
  SELECT public.get_server_role(target_server_id) INTO caller_role;
  IF caller_role IS DISTINCT FROM 'owner' AND target_user_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  SELECT COUNT(*) INTO owner_count
  FROM public.server_members
  WHERE server_members.server_id = target_server_id
    AND server_members.role = 'owner';
  IF owner_count <= 1 AND target_user_id IN (SELECT user_id FROM public.server_members WHERE server_id = target_server_id AND role = 'owner') THEN
    RAISE EXCEPTION 'cannot remove the last owner';
  END IF;

  DELETE FROM public.server_members
  WHERE server_members.server_id = remove_member.target_server_id
    AND server_members.user_id = remove_member.target_user_id;
END;
$$;

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 10. RPC: create_server_invite (pgcrypto-generated code)
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

DROP FUNCTION IF EXISTS public.create_server_invite(BIGINT, INT, TIMESTAMPTZ) CASCADE;
CREATE FUNCTION public.create_server_invite(
  target_server_id BIGINT,
  max_uses_limit INT DEFAULT 0,
  expire_at TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE (invite_id BIGINT, code TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_role TEXT;
  v_invite_id BIGINT;
  v_code TEXT;
  v_attempts INT := 0;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;

  v_role := public.get_server_role(target_server_id);
  IF v_role NOT IN ('owner','moderator') THEN
    RAISE EXCEPTION 'only owner or moderator can create invites';
  END IF;

  IF max_uses_limit < 0 THEN
    RAISE EXCEPTION 'max_uses must be >= 0';
  END IF;

  IF expire_at IS NOT NULL AND expire_at <= now() THEN
    RAISE EXCEPTION 'expires_at must be in the future';
  END IF;

  -- Generate a random 16-char hex code, retry on collision
  LOOP
    v_code := encode(public.gen_random_bytes(8), 'hex');
    BEGIN
      INSERT INTO public.server_invites (server_id, creator_id, code, max_uses, expires_at)
      VALUES (target_server_id, auth.uid(), v_code, max_uses_limit, expire_at)
      RETURNING id INTO v_invite_id;
      EXIT;
    EXCEPTION WHEN unique_violation THEN
      v_attempts := v_attempts + 1;
      IF v_attempts >= 5 THEN
        RAISE EXCEPTION 'failed to generate unique invite code';
      END IF;
    END;
  END LOOP;

  RETURN QUERY SELECT v_invite_id, v_code;
END;
$$;

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 11. RPC: join_server_by_invite
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

DROP FUNCTION IF EXISTS public.join_server_by_invite(TEXT) CASCADE;
CREATE FUNCTION public.join_server_by_invite(invite_code TEXT)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_invite public.server_invites%ROWTYPE;
  v_uid UUID;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;

  -- Atomically lock the invite row, check conditions, then join
  SELECT * INTO v_invite FROM public.server_invites WHERE code = invite_code FOR UPDATE;
  IF v_invite.id IS NULL THEN
    RAISE EXCEPTION 'invite not found';
  END IF;

  -- Check revoked
  IF v_invite.revoked_at IS NOT NULL THEN
    RAISE EXCEPTION 'invite has been revoked';
  END IF;

  -- Check expiry
  IF v_invite.expires_at IS NOT NULL AND v_invite.expires_at < now() THEN
    RAISE EXCEPTION 'invite has expired';
  END IF;

  -- Check max uses
  IF v_invite.max_uses > 0 AND v_invite.uses >= v_invite.max_uses THEN
    RAISE EXCEPTION 'invite has reached maximum uses';
  END IF;

  -- Check if already a member
  IF EXISTS (SELECT 1 FROM public.server_members WHERE server_id = v_invite.server_id AND user_id = v_uid) THEN
    RAISE EXCEPTION 'already a member of this server';
  END IF;

  -- Atomic join: add member AND increment uses in the same locked transaction
  INSERT INTO public.server_members (server_id, user_id, role)
  VALUES (v_invite.server_id, v_uid, 'member');

  UPDATE public.server_invites
  SET uses = uses + 1
  WHERE id = v_invite.id;

  RETURN v_invite.server_id;
END;
$$;

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 12. RPC: revoke_server_invite
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

DROP FUNCTION IF EXISTS public.revoke_server_invite(BIGINT) CASCADE;
CREATE FUNCTION public.revoke_server_invite(invite_id BIGINT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_server_id BIGINT;
  v_creator_id UUID;
  v_role TEXT;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;

  SELECT server_id, creator_id INTO v_server_id, v_creator_id
  FROM public.server_invites WHERE id = invite_id;
  IF v_server_id IS NULL THEN RAISE EXCEPTION 'invite not found'; END IF;

  v_role := public.get_server_role(v_server_id);

  -- Only owner, moderator, or the original creator can revoke
  IF v_role NOT IN ('owner','moderator') AND v_creator_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'not authorized to revoke this invite';
  END IF;

  UPDATE public.server_invites SET revoked_at = now()
  WHERE id = invite_id;
END;
$$;

-- 13. RPC: create_channel
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

DROP FUNCTION IF EXISTS public.create_channel(BIGINT, TEXT, TEXT, INT) CASCADE;
CREATE FUNCTION public.create_channel(
  target_server_id BIGINT,
  channel_name TEXT,
  channel_type TEXT DEFAULT 'text',
  channel_position INT DEFAULT 0
)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_channel_id BIGINT;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;

  IF public.get_server_role(target_server_id) NOT IN ('owner','moderator') THEN
    RAISE EXCEPTION 'only owner or moderator can create channels';
  END IF;

  IF channel_type NOT IN ('text','voice') THEN
    RAISE EXCEPTION 'channel type must be text or voice';
  END IF;

  INSERT INTO public.channels (server_id, name, type, position)
  VALUES (target_server_id, channel_name, channel_type, channel_position)
  RETURNING id INTO v_channel_id;

  RETURN v_channel_id;
END;
$$;

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 13. RPC: update_channel
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

DROP FUNCTION IF EXISTS public.update_channel(BIGINT, TEXT, TEXT, INT) CASCADE;
CREATE FUNCTION public.update_channel(
  channel_id BIGINT,
  new_name TEXT,
  new_type TEXT DEFAULT NULL,
  new_position INT DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_server_id BIGINT;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;

  SELECT server_id INTO v_server_id FROM public.channels WHERE id = channel_id;
  IF v_server_id IS NULL THEN RAISE EXCEPTION 'channel not found'; END IF;

  IF public.get_server_role(v_server_id) NOT IN ('owner','moderator') THEN
    RAISE EXCEPTION 'only owner or moderator can update channels';
  END IF;

  UPDATE public.channels
  SET
    name = COALESCE(update_channel.new_name, name),
    type = COALESCE(update_channel.new_type, type),
    position = COALESCE(update_channel.new_position, position)
  WHERE id = update_channel.channel_id;
END;
$$;

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 14. RPC: delete_channel
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

DROP FUNCTION IF EXISTS public.delete_channel(BIGINT) CASCADE;
CREATE FUNCTION public.delete_channel(channel_id BIGINT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_server_id BIGINT;
  v_text_count INT;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;

  SELECT server_id INTO v_server_id FROM public.channels WHERE id = channel_id;
  IF v_server_id IS NULL THEN RAISE EXCEPTION 'channel not found'; END IF;

  IF public.get_server_role(v_server_id) NOT IN ('owner','moderator') THEN
    RAISE EXCEPTION 'only owner or moderator can delete channels';
  END IF;

  -- Prevent deleting the last text channel
  SELECT COUNT(*) INTO v_text_count
  FROM public.channels
  WHERE server_id = v_server_id AND type = 'text' AND id != delete_channel.channel_id;

  IF v_text_count = 0 THEN
    RAISE EXCEPTION 'cannot delete the last text channel';
  END IF;

  DELETE FROM public.channels WHERE id = delete_channel.channel_id;
END;
$$;

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 16. RPC: soft_delete_message
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

DROP FUNCTION IF EXISTS public.soft_delete_message(BIGINT) CASCADE;
CREATE FUNCTION public.soft_delete_message(message_id BIGINT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_channel_id BIGINT;
  v_author_id UUID;
  v_server_id BIGINT;
  v_role TEXT;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;

  SELECT channel_id, author_id INTO v_channel_id, v_author_id
  FROM public.messages WHERE id = message_id;
  IF v_channel_id IS NULL THEN RAISE EXCEPTION 'message not found'; END IF;

  -- Author can always soft-delete their own
  IF v_author_id = auth.uid() THEN
    UPDATE public.messages SET deleted_at = now() WHERE id = message_id;
    RETURN;
  END IF;

  -- Owner/moderator can soft-delete in their server
  SELECT server_id INTO v_server_id FROM public.channels WHERE id = v_channel_id;
  v_role := public.get_server_role(v_server_id);
  IF v_role IN ('owner','moderator') THEN
    UPDATE public.messages SET deleted_at = now() WHERE id = message_id;
    RETURN;
  END IF;

  RAISE EXCEPTION 'not authorized to delete this message';
END;
$$;

-- 16. RPC: soft_delete_direct_message
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

DROP FUNCTION IF EXISTS public.soft_delete_direct_message(BIGINT) CASCADE;
CREATE FUNCTION public.soft_delete_direct_message(message_id BIGINT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;

  IF NOT EXISTS (SELECT 1 FROM public.direct_messages WHERE id = message_id AND author_id = auth.uid()) THEN
    RAISE EXCEPTION 'not authorized to delete this message';
  END IF;

  UPDATE public.direct_messages SET deleted_at = now() WHERE id = message_id;
END;
$$;

-- 17. RPC: create_direct_conversation
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

DROP FUNCTION IF EXISTS public.create_direct_conversation(UUID) CASCADE;
CREATE FUNCTION public.create_direct_conversation(other_user_id UUID)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_conv_id BIGINT;
  v_uid UUID;
  v_existing BIGINT;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;

  IF other_user_id = v_uid THEN
    RAISE EXCEPTION 'cannot create conversation with yourself';
  END IF;

  -- Target user must exist
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = other_user_id) THEN
    RAISE EXCEPTION 'user not found';
  END IF;

  -- Return existing conversation if one already exists between these two users
  SELECT dcm1.conversation_id INTO v_existing
  FROM public.direct_conversation_members dcm1
  JOIN public.direct_conversation_members dcm2 ON dcm2.conversation_id = dcm1.conversation_id
  WHERE dcm1.user_id = v_uid AND dcm2.user_id = other_user_id
  LIMIT 1;

  IF v_existing IS NOT NULL THEN
    RETURN v_existing;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.blocks
    WHERE (blocker_id = v_uid AND blocked_id = other_user_id)
       OR (blocker_id = other_user_id AND blocked_id = v_uid)
  ) THEN
    RAISE EXCEPTION 'cannot start conversation – user is blocked';
  END IF;

  INSERT INTO public.direct_conversations DEFAULT VALUES
  RETURNING id INTO v_conv_id;

  INSERT INTO public.direct_conversation_members (conversation_id, user_id)
  VALUES (v_conv_id, v_uid);

  INSERT INTO public.direct_conversation_members (conversation_id, user_id)
  VALUES (v_conv_id, other_user_id);

  RETURN v_conv_id;
END;
$$;

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 16. RLS — ENABLE
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.servers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.server_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.direct_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.direct_conversation_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.direct_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.server_invites ENABLE ROW LEVEL SECURITY;

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 17. RLS — POLICIES
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

-- 17.1 — Profiles
DROP POLICY IF EXISTS profiles_read_authed ON public.profiles;
CREATE POLICY profiles_read_authed ON public.profiles
  FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS profiles_update_own ON public.profiles;
CREATE POLICY profiles_update_own ON public.profiles
  FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- 17.2 — Servers
DROP POLICY IF EXISTS servers_select_member ON public.servers;
CREATE POLICY servers_select_member ON public.servers
  FOR SELECT USING (public.is_server_member(id));

DROP POLICY IF EXISTS servers_update_owner ON public.servers;
CREATE POLICY servers_update_owner ON public.servers
  FOR UPDATE USING (auth.uid() = owner_id) WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS servers_delete_owner ON public.servers;
CREATE POLICY servers_delete_owner ON public.servers
  FOR DELETE USING (auth.uid() = owner_id);

-- 17.3 — Server members (SD helpers → no RLS recursion)
DROP POLICY IF EXISTS members_select ON public.server_members;
CREATE POLICY members_select ON public.server_members
  FOR SELECT USING (public.is_server_member(server_id));

DROP POLICY IF EXISTS members_update_owner ON public.server_members;
CREATE POLICY members_update_owner ON public.server_members
  FOR UPDATE USING (public.get_server_role(server_id) = 'owner')
  WITH CHECK (public.get_server_role(server_id) = 'owner');

DROP POLICY IF EXISTS members_delete_self ON public.server_members;
CREATE POLICY members_delete_self ON public.server_members
  FOR DELETE USING (auth.uid() = user_id);

-- 17.4 — Channels
DROP POLICY IF EXISTS channels_select ON public.channels;
CREATE POLICY channels_select ON public.channels
  FOR SELECT USING (public.is_server_member(server_id));

-- 17.5 — Messages (deleted_at IS NULL — soft delete)
DROP POLICY IF EXISTS messages_select ON public.messages;
CREATE POLICY messages_select ON public.messages
  FOR SELECT USING (
    deleted_at IS NULL
    AND EXISTS (
      SELECT 1 FROM public.channels c
      WHERE c.id = messages.channel_id
        AND public.is_server_member(c.server_id)
    )
  );

DROP POLICY IF EXISTS messages_insert ON public.messages;
CREATE POLICY messages_insert ON public.messages
  FOR INSERT WITH CHECK (
    author_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.channels c
      WHERE c.id = messages.channel_id
        AND public.is_server_member(c.server_id)
    )
  );

DROP POLICY IF EXISTS messages_update_own ON public.messages;
CREATE POLICY messages_update_own ON public.messages
  FOR UPDATE USING (
    author_id = auth.uid()
    AND deleted_at IS NULL
    AND EXISTS (
      SELECT 1 FROM public.channels c
      WHERE c.id = messages.channel_id
        AND public.is_server_member(c.server_id)
    )
  )
  WITH CHECK (author_id = auth.uid());

-- NOTE: No messages_moderate policy. Moderators use soft_delete_message RPC only.

-- 17.6 — Direct conversations
DROP POLICY IF EXISTS dm_conversation_select ON public.direct_conversations;
CREATE POLICY dm_conversation_select ON public.direct_conversations
  FOR SELECT USING (public.is_dm_member(id));

-- 17.7 — Direct conversation members
DROP POLICY IF EXISTS dm_members_select ON public.direct_conversation_members;
CREATE POLICY dm_members_select ON public.direct_conversation_members
  FOR SELECT USING (public.is_dm_member(conversation_id));

-- 17.8 — Direct messages (deleted_at IS NULL — soft delete)
DROP POLICY IF EXISTS dm_messages_select ON public.direct_messages;
CREATE POLICY dm_messages_select ON public.direct_messages
  FOR SELECT USING (
    deleted_at IS NULL
    AND public.is_dm_member(conversation_id)
  );

DROP POLICY IF EXISTS dm_messages_insert ON public.direct_messages;
CREATE POLICY dm_messages_insert ON public.direct_messages
  FOR INSERT WITH CHECK (
    author_id = auth.uid()
    AND public.is_dm_member(conversation_id)
    AND NOT EXISTS (
      SELECT 1 FROM public.direct_conversation_members dcm
      WHERE dcm.conversation_id = direct_messages.conversation_id
        AND dcm.user_id != direct_messages.author_id
        AND public.is_blocked(dcm.user_id)
    )
  );

DROP POLICY IF EXISTS dm_messages_update_own ON public.direct_messages;
CREATE POLICY dm_messages_update_own ON public.direct_messages
  FOR UPDATE USING (
    author_id = auth.uid()
    AND deleted_at IS NULL
    AND public.is_dm_member(conversation_id)
  )
  WITH CHECK (author_id = auth.uid());

-- 17.9 — Blocks
DROP POLICY IF EXISTS blocks_select_own ON public.blocks;
CREATE POLICY blocks_select_own ON public.blocks
  FOR SELECT USING (auth.uid() = blocker_id);

DROP POLICY IF EXISTS blocks_insert_own ON public.blocks;
CREATE POLICY blocks_insert_own ON public.blocks
  FOR INSERT WITH CHECK (auth.uid() = blocker_id);

DROP POLICY IF EXISTS blocks_delete_own ON public.blocks;
CREATE POLICY blocks_delete_own ON public.blocks
  FOR DELETE USING (auth.uid() = blocker_id);

-- 17.10 — Reports
DROP POLICY IF EXISTS reports_insert_own ON public.reports;
CREATE POLICY reports_insert_own ON public.reports
  FOR INSERT WITH CHECK (auth.uid() = reporter_id);

DROP POLICY IF EXISTS reports_select_own ON public.reports;
CREATE POLICY reports_select_own ON public.reports
  FOR SELECT USING (auth.uid() = reporter_id);

-- 17.11 — Server invites (only owner/moderator/creator can see)
DROP POLICY IF EXISTS invites_select_owner_mod_creator ON public.server_invites;
CREATE POLICY invites_select_owner_mod_creator ON public.server_invites
  FOR SELECT USING (
    creator_id = auth.uid()
    OR public.get_server_role(server_id) IN ('owner','moderator')
  );

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 18. REALTIME PUBLICATION (идемпотентно)
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    CREATE PUBLICATION supabase_realtime;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'direct_messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.direct_messages;
  END IF;
END $$;

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 19. REVOKE — Минимизация прав
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC, anon;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC, anon;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC, anon;

GRANT USAGE ON SCHEMA public TO authenticated;

-- Чтение таблиц через RLS
GRANT SELECT ON ALL TABLES IN SCHEMA public TO authenticated;

-- Profiles: column-level UPDATE только пользовательских полей
GRANT UPDATE (username, display_name, avatar_url, status) ON TABLE public.profiles TO authenticated;

-- Servers: column-level UPDATE только name и icon_url
GRANT UPDATE (name, icon_url) ON TABLE public.servers TO authenticated;
GRANT DELETE ON TABLE public.servers TO authenticated;

-- Messages, DM: только INSERT и column-level UPDATE(content) через RLS;
-- DELETE отозван — мягкое удаление через RPC
GRANT INSERT ON TABLE public.messages TO authenticated;
GRANT UPDATE (content) ON TABLE public.messages TO authenticated;
GRANT INSERT ON TABLE public.direct_messages TO authenticated;
GRANT UPDATE (content) ON TABLE public.direct_messages TO authenticated;
GRANT INSERT, DELETE ON TABLE public.blocks TO authenticated;

-- Reports: только INSERT и SELECT; UPDATE и DELETE отозваны — жалоба не редактируется
GRANT INSERT ON TABLE public.reports TO authenticated;

-- server_members, direct_conversation_members, channels, server_invites: только SELECT
GRANT SELECT ON TABLE public.server_members TO authenticated;
GRANT SELECT ON TABLE public.direct_conversation_members TO authenticated;
GRANT SELECT ON TABLE public.channels TO authenticated;
GRANT SELECT ON TABLE public.server_invites TO authenticated;

-- Sequences: USAGE только для таблиц, куда клиент вставляет напрямую
GRANT USAGE ON SEQUENCE public.messages_id_seq TO authenticated;
GRANT USAGE ON SEQUENCE public.direct_messages_id_seq TO authenticated;
GRANT USAGE ON SEQUENCE public.reports_id_seq TO authenticated;

-- RPC-функции, доступные клиенту
GRANT EXECUTE ON FUNCTION public.create_server(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.transfer_server_ownership(BIGINT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_member_role(BIGINT, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.remove_member(BIGINT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_server_invite(BIGINT, INT, TIMESTAMPTZ) TO authenticated;
GRANT EXECUTE ON FUNCTION public.revoke_server_invite(BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.join_server_by_invite(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_channel(BIGINT, TEXT, TEXT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_channel(BIGINT, TEXT, TEXT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_channel(BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.soft_delete_message(BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.soft_delete_direct_message(BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_direct_conversation(UUID) TO authenticated;

-- Helper-функции: RLS-политики вызывают их от имени authenticated
GRANT EXECUTE ON FUNCTION public.is_server_member(BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_server_role(BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_dm_member(BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_blocked(UUID) TO authenticated;