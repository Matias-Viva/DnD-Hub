-- ============================================================
-- Migration 004: health check
-- ============================================================


-- ------------------------------------------------------------
-- health_check
-- Lightweight RPC used by clients to verify database
-- connectivity. SECURITY DEFINER so it runs regardless of the
-- caller's role and does not depend on any table being readable.
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.health_check()
RETURNS TIMESTAMPTZ
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
    SELECT NOW();
$$;

GRANT EXECUTE ON FUNCTION public.health_check() TO anon, authenticated;
