-- ============================================================
-- Migration 002: compendium
-- Reference content: races, classes, spells, creatures, items.
-- All tables share the same access pattern:
--   - is_active flag for admin enable/disable
--   - source_id FK for content origin and access control
--   - slug for human-readable API references
--   - jsonb data for flexible type-specific attributes
-- Source-gated reads go through public.has_source_access(),
-- admin writes through public.is_admin() (both defined in 001).
-- ============================================================


-- ------------------------------------------------------------
-- RACES
-- ------------------------------------------------------------

CREATE TABLE public.races (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id       UUID        NOT NULL REFERENCES public.sources(id) ON DELETE RESTRICT,
    slug            TEXT        NOT NULL,
    name            TEXT        NOT NULL,
    is_active       BOOLEAN     NOT NULL DEFAULT TRUE,
    ability_bonuses JSONB       NOT NULL DEFAULT '[]',
    traits          JSONB       NOT NULL DEFAULT '[]',
    data            JSONB       NOT NULL DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (source_id, slug)
);

CREATE TRIGGER on_races_updated
    BEFORE UPDATE ON public.races
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- subraces.source_id lets an expansion add new subraces to a core
-- race; access requires both the subrace's source and the race's.
CREATE TABLE public.subraces (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    race_id         UUID        NOT NULL REFERENCES public.races(id) ON DELETE CASCADE,
    source_id       UUID        NOT NULL REFERENCES public.sources(id) ON DELETE RESTRICT,
    slug            TEXT        NOT NULL,
    name            TEXT        NOT NULL,
    is_active       BOOLEAN     NOT NULL DEFAULT TRUE,
    ability_bonuses JSONB       NOT NULL DEFAULT '[]',
    traits          JSONB       NOT NULL DEFAULT '[]',
    data            JSONB       NOT NULL DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (race_id, slug)
);

CREATE TRIGGER on_subraces_updated
    BEFORE UPDATE ON public.subraces
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- RLS
ALTER TABLE public.races    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subraces ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view active races from accessible sources"
    ON public.races FOR SELECT
    USING (is_active = TRUE AND public.has_source_access(source_id));

CREATE POLICY "Admins can manage races"
    ON public.races FOR ALL
    USING (public.is_admin());

CREATE POLICY "Anyone can view active subraces from accessible sources"
    ON public.subraces FOR SELECT
    USING (
        is_active = TRUE
        AND public.has_source_access(source_id)
        AND EXISTS (
            SELECT 1 FROM public.races r
            WHERE r.id = race_id
            AND r.is_active = TRUE
            AND public.has_source_access(r.source_id)
        )
    );

CREATE POLICY "Admins can manage subraces"
    ON public.subraces FOR ALL
    USING (public.is_admin());


-- ------------------------------------------------------------
-- CLASSES
-- ------------------------------------------------------------

CREATE TABLE public.classes (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id       UUID        NOT NULL REFERENCES public.sources(id) ON DELETE RESTRICT,
    slug            TEXT        NOT NULL,
    name            TEXT        NOT NULL,
    is_active       BOOLEAN     NOT NULL DEFAULT TRUE,
    hit_die         INT         NOT NULL,
    data            JSONB       NOT NULL DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (source_id, slug)
);

CREATE TRIGGER on_classes_updated
    BEFORE UPDATE ON public.classes
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- subclasses.source_id mirrors subraces: an expansion can add
-- subclasses to a core class.
CREATE TABLE public.subclasses (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    class_id    UUID        NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
    source_id   UUID        NOT NULL REFERENCES public.sources(id) ON DELETE RESTRICT,
    slug        TEXT        NOT NULL,
    name        TEXT        NOT NULL,
    is_active   BOOLEAN     NOT NULL DEFAULT TRUE,
    data        JSONB       NOT NULL DEFAULT '{}',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (class_id, slug)
);

CREATE TRIGGER on_subclasses_updated
    BEFORE UPDATE ON public.subclasses
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- RLS
ALTER TABLE public.classes    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subclasses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view active classes from accessible sources"
    ON public.classes FOR SELECT
    USING (is_active = TRUE AND public.has_source_access(source_id));

CREATE POLICY "Admins can manage classes"
    ON public.classes FOR ALL
    USING (public.is_admin());

CREATE POLICY "Anyone can view active subclasses from accessible sources"
    ON public.subclasses FOR SELECT
    USING (
        is_active = TRUE
        AND public.has_source_access(source_id)
        AND EXISTS (
            SELECT 1 FROM public.classes c
            WHERE c.id = class_id
            AND c.is_active = TRUE
            AND public.has_source_access(c.source_id)
        )
    );

CREATE POLICY "Admins can manage subclasses"
    ON public.subclasses FOR ALL
    USING (public.is_admin());


-- ------------------------------------------------------------
-- SPELLS
-- level and school are extracted from data for query filtering
-- ------------------------------------------------------------

CREATE TABLE public.spells (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id   UUID        NOT NULL REFERENCES public.sources(id) ON DELETE RESTRICT,
    slug        TEXT        NOT NULL,
    name        TEXT        NOT NULL,
    is_active   BOOLEAN     NOT NULL DEFAULT TRUE,
    level       INT         NOT NULL CHECK (level >= 0 AND level <= 9),
    school      TEXT        NOT NULL CHECK (school IN (
                    'abjuration', 'conjuration', 'divination', 'enchantment',
                    'evocation', 'illusion', 'necromancy', 'transmutation'
                )),
    data        JSONB       NOT NULL DEFAULT '{}',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (source_id, slug)
);

CREATE TRIGGER on_spells_updated
    BEFORE UPDATE ON public.spells
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- RLS
ALTER TABLE public.spells ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view active spells from accessible sources"
    ON public.spells FOR SELECT
    USING (is_active = TRUE AND public.has_source_access(source_id));

CREATE POLICY "Admins can manage spells"
    ON public.spells FOR ALL
    USING (public.is_admin());


-- ------------------------------------------------------------
-- CREATURES
-- challenge_rating and creature_type extracted for filtering
-- ------------------------------------------------------------

CREATE TABLE public.creatures (
    id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id        UUID        NOT NULL REFERENCES public.sources(id) ON DELETE RESTRICT,
    slug             TEXT        NOT NULL,
    name             TEXT        NOT NULL,
    is_active        BOOLEAN     NOT NULL DEFAULT TRUE,
    creature_type    TEXT        NOT NULL CHECK (creature_type IN (
                        'aberration', 'beast', 'celestial', 'construct',
                        'dragon', 'elemental', 'fey', 'fiend', 'giant',
                        'humanoid', 'monstrosity', 'ooze', 'plant', 'undead'
                    )),
    challenge_rating NUMERIC(5,2) NOT NULL CHECK (challenge_rating >= 0),
    data             JSONB       NOT NULL DEFAULT '{}',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (source_id, slug)
);

CREATE TRIGGER on_creatures_updated
    BEFORE UPDATE ON public.creatures
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- RLS
ALTER TABLE public.creatures ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view active creatures from accessible sources"
    ON public.creatures FOR SELECT
    USING (is_active = TRUE AND public.has_source_access(source_id));

CREATE POLICY "Admins can manage creatures"
    ON public.creatures FOR ALL
    USING (public.is_admin());


-- ------------------------------------------------------------
-- ITEMS
-- item_type extracted for filtering (weapon, armor, potion...)
-- ------------------------------------------------------------

CREATE TABLE public.items (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id   UUID        NOT NULL REFERENCES public.sources(id) ON DELETE RESTRICT,
    slug        TEXT        NOT NULL,
    name        TEXT        NOT NULL,
    is_active   BOOLEAN     NOT NULL DEFAULT TRUE,
    item_type   TEXT        NOT NULL CHECK (item_type IN (
                    'weapon', 'armor', 'shield', 'potion', 'scroll',
                    'wand', 'rod', 'staff', 'ring', 'wondrous_item',
                    'ammunition', 'gear', 'tool', 'vehicle', 'other'
                )),
    data        JSONB       NOT NULL DEFAULT '{}',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (source_id, slug)
);

CREATE TRIGGER on_items_updated
    BEFORE UPDATE ON public.items
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- RLS
ALTER TABLE public.items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view active items from accessible sources"
    ON public.items FOR SELECT
    USING (is_active = TRUE AND public.has_source_access(source_id));

CREATE POLICY "Admins can manage items"
    ON public.items FOR ALL
    USING (public.is_admin());


-- ------------------------------------------------------------
-- INDEXES
-- ------------------------------------------------------------

CREATE INDEX idx_races_source_id      ON public.races(source_id);
CREATE INDEX idx_subraces_source_id   ON public.subraces(source_id);
CREATE INDEX idx_subraces_race_id     ON public.subraces(race_id);
CREATE INDEX idx_classes_source_id    ON public.classes(source_id);
CREATE INDEX idx_subclasses_source_id ON public.subclasses(source_id);
CREATE INDEX idx_subclasses_class_id  ON public.subclasses(class_id);
CREATE INDEX idx_spells_source_id     ON public.spells(source_id);
CREATE INDEX idx_spells_level         ON public.spells(level);
CREATE INDEX idx_spells_school        ON public.spells(school);
CREATE INDEX idx_creatures_source_id  ON public.creatures(source_id);
CREATE INDEX idx_creatures_cr         ON public.creatures(challenge_rating);
CREATE INDEX idx_creatures_type       ON public.creatures(creature_type);
CREATE INDEX idx_items_source_id      ON public.items(source_id);
CREATE INDEX idx_items_type           ON public.items(item_type);