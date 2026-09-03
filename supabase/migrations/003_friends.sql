-- ============================================================
-- Squall — Friends System (003)
-- ============================================================
-- Выполнить после 002_social_voice.sql
-- ============================================================

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 1. FRIENDS VIEW (accepted friend_requests)
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

CREATE OR REPLACE VIEW public.friends AS
SELECT
  CASE WHEN sender_id = auth.uid() THEN receiver_id ELSE sender_id END AS friend_id,
  GREATEST(fr.created_at, fr.updated_at) AS became_friends_at
FROM public.friend_requests fr
WHERE fr.status = 'accepted'
  AND (fr.sender_id = auth.uid() OR fr.receiver_id = auth.uid());

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 2. SAFE FUNCTION: friend count (SD, не RLS)
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

DROP FUNCTION IF EXISTS public.is_friend(UUID) CASCADE;
CREATE FUNCTION public.is_friend(other_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.friend_requests
    WHERE status = 'accepted'
      AND (
        (sender_id = auth.uid() AND receiver_id = is_friend.other_user_id) OR
        (sender_id = is_friend.other_user_id AND receiver_id = auth.uid())
      )
  );
END;
$$;

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 3. RLS UPDATES FOR friend_requests (corrected)
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

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 4. GRANTS
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

GRANT SELECT ON public.friends TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_friend(UUID) TO authenticated;