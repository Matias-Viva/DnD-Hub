-- ============================================================
-- Migration 001: users and sources
-- ============================================================


-- ------------------------------------------------------------
-- handle_updated_at
-- Reusable trigger function for updated_at columns.
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


-- ------------------------------------------------------------
-- USERS
-- Extends Supabase auth.users with application profile data.
-- Created automatically on first login via trigger.
-- ------------------------------------------------------------

CREATE TABLE public.users (
    id          UUID        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email       TEXT        NOT NULL UNIQUE,
    username    TEXT        NOT NULL UNIQUE,
    avatar_url  TEXT,
    role        TEXT        NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER on_users_updated
    BEFORE UPDATE ON public.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Trigger: auto-create profile row when a user signs up via Supabase Auth.
-- Resolves username collisions (e.g. foo@a.com and foo@b.com) by
-- appending a numeric suffix until a free username is found.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
    base_username TEXT;
    candidate     TEXT;
    suffix        INT := 1;
BEGIN
    base_username := COALESCE(
        NEW.raw_user_meta_data->>'username',
        split_part(NEW.email, '@', 1)
    );
    candidate := base_username;

    WHILE EXISTS (SELECT 1 FROM public.users WHERE username = candidate) LOOP
        suffix := suffix + 1;
        candidate := base_username || suffix::TEXT;
    END LOOP;

    INSERT INTO public.users (id, email, username)
    VALUES (NEW.id, NEW.email, candidate);
    RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Trigger: enforce that user-driven updates cannot change identity
-- or role fields. Service-role writes (no auth context) and nested
-- trigger updates (e.g. the auth email sync below) bypass the check.
CREATE OR REPLACE FUNCTION public.users_enforce_immutable_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF auth.uid() IS NULL OR pg_trigger_depth() > 1 THEN
        RETURN NEW;
    END IF;

    IF NEW.id    IS DISTINCT FROM OLD.id    THEN RAISE EXCEPTION 'users.id is immutable';   END IF;
    IF NEW.role  IS DISTINCT FROM OLD.role  THEN RAISE EXCEPTION 'users.role is immutable from client'; END IF;
    IF NEW.email IS DISTINCT FROM OLD.email THEN RAISE EXCEPTION 'users.email is immutable from client'; END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER on_users_enforce_immutable
    BEFORE UPDATE ON public.users
    FOR EACH ROW EXECUTE FUNCTION public.users_enforce_immutable_fields();

-- Trigger: keep public.users.email in sync when auth.users.email changes.
-- Runs at trigger depth 2, so users_enforce_immutable_fields skips it.
CREATE OR REPLACE FUNCTION public.handle_auth_user_updated()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
    IF NEW.email IS DISTINCT FROM OLD.email THEN
        UPDATE public.users SET email = NEW.email WHERE id = NEW.id;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_updated
    AFTER UPDATE OF email ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_auth_user_updated();


-- ------------------------------------------------------------
-- is_admin
-- SECURITY DEFINER so callers checking admin status from within a
-- policy on public.users don't re-enter the same policy chain.
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.users
        WHERE id = auth.uid() AND role = 'admin'
    );
$$;


-- RLS
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own profile"
    ON public.users FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
    ON public.users FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

CREATE POLICY "Admins can view all profiles"
    ON public.users FOR SELECT
    USING (public.is_admin());


-- ------------------------------------------------------------
-- SOURCES
-- Catalog of content sources (books, SRD versions, etc).
-- Managed by admins. Users acquire sources via user_sources.
-- ------------------------------------------------------------

CREATE TABLE public.sources (
    id          UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    slug        TEXT          NOT NULL UNIQUE,
    name        TEXT          NOT NULL,
    edition     TEXT          NOT NULL,
    price       NUMERIC(10,2) NOT NULL DEFAULT 0.00 CHECK (price >= 0),
    is_active   BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- RLS
ALTER TABLE public.sources ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view active sources"
    ON public.sources FOR SELECT
    USING (is_active = TRUE);

CREATE POLICY "Admins can manage sources"
    ON public.sources FOR ALL
    USING (public.is_admin());


-- ------------------------------------------------------------
-- USER_SOURCES
-- Records which sources each user has acquired.
-- Free sources (price = 0) don't need a row here — access is
-- granted by the price check in public.has_source_access().
-- Writes are performed by the backend with the service role
-- after payment verification (no INSERT/UPDATE policy by design).
-- ------------------------------------------------------------

CREATE TABLE public.user_sources (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    source_id   UUID        NOT NULL REFERENCES public.sources(id) ON DELETE CASCADE,
    payment_id  TEXT        UNIQUE,
    acquired_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (user_id, source_id)
);

CREATE INDEX idx_user_sources_source_id ON public.user_sources(source_id);


-- ------------------------------------------------------------
-- has_source_access
-- Whether the current auth.uid() can read content from a source.
-- SECURITY DEFINER so it bypasses RLS on sources / user_sources
-- when called from inside compendium policies.
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.has_source_access(p_source_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.sources s
        WHERE s.id = p_source_id
        AND s.is_active = TRUE
        AND (
            s.price = 0
            OR EXISTS (
                SELECT 1 FROM public.user_sources us
                WHERE us.source_id = s.id AND us.user_id = auth.uid()
            )
        )
    );
$$;


-- RLS
ALTER TABLE public.user_sources ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own acquired sources"
    ON public.user_sources FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all acquired sources"
    ON public.user_sources FOR SELECT
    USING (public.is_admin());