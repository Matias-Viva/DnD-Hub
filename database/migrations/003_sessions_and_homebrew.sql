-- ============================================================
-- Migration 003: sessions, characters and homebrew content
-- handle_updated_at() and is_admin() are defined in 001.
-- ============================================================


-- ------------------------------------------------------------
-- generate_invite_code
-- Loops until it finds an unused 8-char code, so the table's
-- DEFAULT can't collide with an existing session and surface a
-- cryptic UNIQUE violation to the user.
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.generate_invite_code()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
    code TEXT;
BEGIN
    LOOP
        code := upper(substring(gen_random_uuid()::text, 1, 8));
        EXIT WHEN NOT EXISTS (
            SELECT 1 FROM public.game_sessions WHERE invite_code = code
        );
    END LOOP;
    RETURN code;
END;
$$;


-- ------------------------------------------------------------
-- GAME SESSIONS
-- ------------------------------------------------------------

CREATE TABLE public.game_sessions (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id    UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    name        TEXT        NOT NULL,
    description TEXT,
    status      TEXT        NOT NULL DEFAULT 'active'
                            CHECK (status IN ('active', 'paused', 'finished')),
    invite_code TEXT        NOT NULL UNIQUE DEFAULT public.generate_invite_code(),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER on_game_session_updated
    BEFORE UPDATE ON public.game_sessions
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();


-- ------------------------------------------------------------
-- SESSION MEMBERS
-- Joining a session is performed by the backend with the service
-- role after it validates the invite_code (no INSERT policy).
-- The owner is auto-added as DM by handle_new_session().
-- ------------------------------------------------------------

CREATE TABLE public.session_members (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id  UUID        NOT NULL REFERENCES public.game_sessions(id) ON DELETE CASCADE,
    user_id     UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    role        TEXT        NOT NULL DEFAULT 'player'
                            CHECK (role IN ('dm', 'player')),
    joined_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (session_id, user_id)
);

CREATE OR REPLACE FUNCTION public.handle_new_session()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
    INSERT INTO public.session_members (session_id, user_id, role)
    VALUES (NEW.id, NEW.owner_id, 'dm');
    RETURN NEW;
END;
$$;

CREATE TRIGGER on_game_session_created
    AFTER INSERT ON public.game_sessions
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_session();


-- ------------------------------------------------------------
-- CHARACTERS
-- ------------------------------------------------------------

CREATE TABLE public.characters (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id    UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    session_id  UUID        REFERENCES public.game_sessions(id) ON DELETE SET NULL,
    name        TEXT        NOT NULL,
    level       INT         NOT NULL DEFAULT 1 CHECK (level >= 1 AND level <= 20),
    data        JSONB       NOT NULL DEFAULT '{}',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER on_character_updated
    BEFORE UPDATE ON public.characters
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();


-- ------------------------------------------------------------
-- HOMEBREW CONTENT
-- ------------------------------------------------------------

CREATE TABLE public.homebrew_content (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id     UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    content_type TEXT        NOT NULL
                             CHECK (content_type IN (
                                 'character', 'creature', 'spell', 'race',
                                 'class', 'item', 'puzzle', 'map', 'plot'
                             )),
    name         TEXT        NOT NULL,
    visibility   TEXT        NOT NULL DEFAULT 'private'
                             CHECK (visibility IN ('private', 'shared', 'public', 'paid')),
    price        NUMERIC(10,2) NOT NULL DEFAULT 0.00 CHECK (price >= 0),
    is_active    BOOLEAN     NOT NULL DEFAULT TRUE,
    data         JSONB       NOT NULL DEFAULT '{}',
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER on_homebrew_updated
    BEFORE UPDATE ON public.homebrew_content
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();


-- ------------------------------------------------------------
-- USER HOMEBREW ACCESS
-- Writes are performed by the backend with the service role after
-- payment verification (no INSERT policy by design, mirroring
-- user_sources).
-- ------------------------------------------------------------

CREATE TABLE public.user_homebrew_access (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    homebrew_id UUID        NOT NULL REFERENCES public.homebrew_content(id) ON DELETE CASCADE,
    payment_id  TEXT        UNIQUE,
    acquired_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (user_id, homebrew_id)
);


-- ------------------------------------------------------------
-- RLS — defined after all tables exist to avoid forward refs
-- ------------------------------------------------------------

ALTER TABLE public.game_sessions        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.session_members      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.characters           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.homebrew_content     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_homebrew_access ENABLE ROW LEVEL SECURITY;

-- game_sessions
CREATE POLICY "Session members can view their sessions"
    ON public.game_sessions FOR SELECT
    USING (
        owner_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM public.session_members sm
            WHERE sm.session_id = id AND sm.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can create sessions"
    ON public.game_sessions FOR INSERT
    WITH CHECK (owner_id = auth.uid());

CREATE POLICY "Owners can update their sessions"
    ON public.game_sessions FOR UPDATE
    USING (owner_id = auth.uid())
    WITH CHECK (owner_id = auth.uid());

CREATE POLICY "Owners can delete their sessions"
    ON public.game_sessions FOR DELETE
    USING (owner_id = auth.uid());

-- session_members (no INSERT — backend handles join after invite_code check)
CREATE POLICY "Session members can view membership"
    ON public.session_members FOR SELECT
    USING (
        user_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM public.game_sessions gs
            WHERE gs.id = session_id AND gs.owner_id = auth.uid()
        )
    );

CREATE POLICY "Owners and members can leave sessions"
    ON public.session_members FOR DELETE
    USING (
        user_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM public.game_sessions gs
            WHERE gs.id = session_id AND gs.owner_id = auth.uid()
        )
    );

-- characters
CREATE POLICY "Users can view their own characters"
    ON public.characters FOR SELECT
    USING (owner_id = auth.uid());

CREATE POLICY "Session members can view characters in their session"
    ON public.characters FOR SELECT
    USING (
        session_id IS NOT NULL
        AND EXISTS (
            SELECT 1 FROM public.session_members sm
            WHERE sm.session_id = characters.session_id
            AND sm.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can create characters"
    ON public.characters FOR INSERT
    WITH CHECK (owner_id = auth.uid());

CREATE POLICY "Users can update their own characters"
    ON public.characters FOR UPDATE
    USING (owner_id = auth.uid())
    WITH CHECK (owner_id = auth.uid());

CREATE POLICY "Users can delete their own characters"
    ON public.characters FOR DELETE
    USING (owner_id = auth.uid());

-- homebrew_content
CREATE POLICY "Users can view their own homebrew"
    ON public.homebrew_content FOR SELECT
    USING (owner_id = auth.uid());

-- 'paid' is intentionally excluded here; paid content is gated by
-- a row in user_homebrew_access (next policy below).
CREATE POLICY "Anyone can view public homebrew"
    ON public.homebrew_content FOR SELECT
    USING (is_active = TRUE AND visibility = 'public');

CREATE POLICY "Users with access can view shared or paid homebrew"
    ON public.homebrew_content FOR SELECT
    USING (
        is_active = TRUE
        AND visibility IN ('shared', 'paid')
        AND EXISTS (
            SELECT 1 FROM public.user_homebrew_access uha
            WHERE uha.homebrew_id = id AND uha.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can create homebrew"
    ON public.homebrew_content FOR INSERT
    WITH CHECK (owner_id = auth.uid());

CREATE POLICY "Users can update their own homebrew"
    ON public.homebrew_content FOR UPDATE
    USING (owner_id = auth.uid())
    WITH CHECK (owner_id = auth.uid());

CREATE POLICY "Users can delete their own homebrew"
    ON public.homebrew_content FOR DELETE
    USING (owner_id = auth.uid());

-- user_homebrew_access (no INSERT — backend handles payment + grant)
CREATE POLICY "Users can view their own homebrew access"
    ON public.user_homebrew_access FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Homebrew owners can view who has access"
    ON public.user_homebrew_access FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.homebrew_content hc
            WHERE hc.id = homebrew_id AND hc.owner_id = auth.uid()
        )
    );

CREATE POLICY "Users can remove their own homebrew access"
    ON public.user_homebrew_access FOR DELETE
    USING (user_id = auth.uid());


-- ------------------------------------------------------------
-- INDEXES
-- ------------------------------------------------------------

CREATE INDEX idx_game_sessions_owner_id      ON public.game_sessions(owner_id);
CREATE INDEX idx_game_sessions_invite_code   ON public.game_sessions(invite_code);
CREATE INDEX idx_session_members_session     ON public.session_members(session_id);
CREATE INDEX idx_session_members_user        ON public.session_members(user_id);
CREATE INDEX idx_characters_owner_id         ON public.characters(owner_id);
CREATE INDEX idx_characters_session_id       ON public.characters(session_id);
CREATE INDEX idx_homebrew_owner_id           ON public.homebrew_content(owner_id);
CREATE INDEX idx_homebrew_content_type       ON public.homebrew_content(content_type);
CREATE INDEX idx_homebrew_visibility         ON public.homebrew_content(visibility);
CREATE INDEX idx_homebrew_data_gin           ON public.homebrew_content USING GIN (data);
CREATE INDEX idx_user_homebrew_access_user   ON public.user_homebrew_access(user_id);
CREATE INDEX idx_user_homebrew_access_hb     ON public.user_homebrew_access(homebrew_id);