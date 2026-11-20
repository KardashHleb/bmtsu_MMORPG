-- =====================================================================
--  bmtsu_MMORPG — database schema v2
--  Target: PostgreSQL 13+
--  Normal form: BCNF (see README.md for the analysis)
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
--  1. Reference tables
-- ---------------------------------------------------------------------

-- Game servers (realms)
CREATE TABLE servers (
    server_id      INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name           VARCHAR(50) NOT NULL UNIQUE,
    region         VARCHAR(30) NOT NULL,
    is_pvp_enabled BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Playable classes (Warrior, Mage, ...)
CREATE TABLE character_classes (
    class_id   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    class_name VARCHAR(30) NOT NULL UNIQUE
);

-- Ability catalogue
CREATE TABLE abilities (
    ability_id   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ability_name VARCHAR(30) NOT NULL UNIQUE
);

-- Which abilities a class is allowed to learn (M:N)
CREATE TABLE class_abilities (
    class_id   INTEGER NOT NULL REFERENCES character_classes (class_id) ON DELETE CASCADE,
    ability_id INTEGER NOT NULL REFERENCES abilities (ability_id)       ON DELETE CASCADE,
    PRIMARY KEY (class_id, ability_id)
);

-- Guild ranks (replaces the free-text "rank" column of v1)
CREATE TABLE guild_ranks (
    rank_code VARCHAR(20) PRIMARY KEY,
    rank_name VARCHAR(30) NOT NULL UNIQUE,
    priority  SMALLINT    NOT NULL UNIQUE CHECK (priority > 0)  -- 1 = highest
);

INSERT INTO guild_ranks (rank_code, rank_name, priority) VALUES
    ('leader',  'Leader',  1),
    ('officer', 'Officer', 2),
    ('member',  'Member',  3);

-- ---------------------------------------------------------------------
--  2. Players and characters
-- ---------------------------------------------------------------------

-- Player accounts
CREATE TABLE accounts (
    account_id    INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email         VARCHAR(255) NOT NULL UNIQUE CHECK (position('@' IN email) > 1),
    username      VARCHAR(50)  NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    last_login    TIMESTAMPTZ,
    is_banned     BOOLEAN      NOT NULL DEFAULT FALSE
);

-- Characters. Server and class are fixed at creation (see trigger below).
CREATE TABLE characters (
    character_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id   INTEGER     NOT NULL REFERENCES accounts (account_id)         ON DELETE CASCADE,
    server_id    INTEGER     NOT NULL REFERENCES servers (server_id)           ON DELETE RESTRICT,
    class_id     INTEGER     NOT NULL REFERENCES character_classes (class_id)  ON DELETE RESTRICT,
    name         VARCHAR(30) NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (server_id, name)              -- a name is unique per server
);

-- Long-term progress (1:1 with characters)
CREATE TABLE character_progress (
    character_id   INTEGER     PRIMARY KEY REFERENCES characters (character_id) ON DELETE CASCADE,
    level          SMALLINT    NOT NULL DEFAULT 1 CHECK (level BETWEEN 1 AND 100),
    experience     BIGINT      NOT NULL DEFAULT 0 CHECK (experience >= 0),
    -- One balance in the smallest coin. Gold/silver/copper are derived:
    -- gold = balance / 10000, silver = balance / 100 % 100, copper = balance % 100
    balance_copper BIGINT      NOT NULL DEFAULT 0 CHECK (balance_copper >= 0),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Volatile in-world state (1:1 with characters, updated very often)
CREATE TABLE character_state (
    character_id   INTEGER     PRIMARY KEY REFERENCES characters (character_id) ON DELETE CASCADE,
    current_health INTEGER     NOT NULL DEFAULT 100 CHECK (current_health >= 0),
    current_mana   INTEGER     NOT NULL DEFAULT 100 CHECK (current_mana >= 0),
    position_x     REAL        NOT NULL DEFAULT 0,
    position_y     REAL        NOT NULL DEFAULT 0,
    position_z     REAL        NOT NULL DEFAULT 0,
    is_online      BOOLEAN     NOT NULL DEFAULT FALSE,
    last_update    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Abilities learned by a character. Must be allowed for the character's class (trigger).
CREATE TABLE character_abilities (
    character_id  INTEGER     NOT NULL REFERENCES characters (character_id) ON DELETE CASCADE,
    ability_id    INTEGER     NOT NULL REFERENCES abilities (ability_id)    ON DELETE CASCADE,
    ability_level SMALLINT    NOT NULL DEFAULT 1 CHECK (ability_level BETWEEN 1 AND 10),
    learned_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (character_id, ability_id)
);

-- ---------------------------------------------------------------------
--  3. Guilds
-- ---------------------------------------------------------------------

-- Guilds. The leader is the member with rank 'leader' (no leader_character_id column).
CREATE TABLE guilds (
    guild_id   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    server_id  INTEGER     NOT NULL REFERENCES servers (server_id) ON DELETE RESTRICT,
    name       VARCHAR(50) NOT NULL,
    tag        VARCHAR(10) NOT NULL,
    motd       TEXT,                       -- message of the day
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (server_id, name),
    UNIQUE (server_id, tag)
);

-- Membership history: one row per "joined -> left" period.
CREATE TABLE guild_memberships (
    membership_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    guild_id      INTEGER     NOT NULL REFERENCES guilds (guild_id)         ON DELETE CASCADE,
    character_id  INTEGER     NOT NULL REFERENCES characters (character_id) ON DELETE CASCADE,
    rank_code     VARCHAR(20) NOT NULL DEFAULT 'member'
                              REFERENCES guild_ranks (rank_code) ON UPDATE CASCADE,
    joined_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    left_at       TIMESTAMPTZ,             -- NULL = still a member
    note          TEXT,
    CHECK (left_at IS NULL OR left_at >= joined_at)
);

-- A character can be in at most one guild at a time (but may rejoin later)
CREATE UNIQUE INDEX uq_active_membership_per_character
    ON guild_memberships (character_id) WHERE left_at IS NULL;

-- A guild has at most one current leader
CREATE UNIQUE INDEX uq_active_leader_per_guild
    ON guild_memberships (guild_id) WHERE rank_code = 'leader' AND left_at IS NULL;

-- ---------------------------------------------------------------------
--  4. Business rules that span several tables (triggers)
-- ---------------------------------------------------------------------

-- 4.1 A character's server and class cannot change after creation,
--     otherwise guild and ability rules below could be silently broken.
CREATE FUNCTION forbid_character_server_class_change() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.server_id <> OLD.server_id OR NEW.class_id <> OLD.class_id THEN
        RAISE EXCEPTION 'Character % cannot change server or class', OLD.character_id
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_characters_immutable
    BEFORE UPDATE OF server_id, class_id ON characters
    FOR EACH ROW EXECUTE FUNCTION forbid_character_server_class_change();

-- 4.2 A guild cannot move to another server.
CREATE FUNCTION forbid_guild_server_change() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.server_id <> OLD.server_id THEN
        RAISE EXCEPTION 'Guild % cannot change server', OLD.guild_id
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_guilds_immutable
    BEFORE UPDATE OF server_id ON guilds
    FOR EACH ROW EXECUTE FUNCTION forbid_guild_server_change();

-- 4.3 A character may learn only abilities allowed for its class.
CREATE FUNCTION check_character_ability() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM characters c
        JOIN class_abilities ca ON ca.class_id = c.class_id
        WHERE c.character_id = NEW.character_id
          AND ca.ability_id  = NEW.ability_id
    ) THEN
        RAISE EXCEPTION 'Ability % is not available for the class of character %',
            NEW.ability_id, NEW.character_id
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_character_abilities_class
    BEFORE INSERT OR UPDATE OF character_id, ability_id ON character_abilities
    FOR EACH ROW EXECUTE FUNCTION check_character_ability();

-- 4.4 A character may join only a guild on its own server.
CREATE FUNCTION check_guild_membership_server() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF (SELECT server_id FROM characters WHERE character_id = NEW.character_id)
       <> (SELECT server_id FROM guilds WHERE guild_id = NEW.guild_id) THEN
        RAISE EXCEPTION 'Character % and guild % are on different servers',
            NEW.character_id, NEW.guild_id
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_guild_memberships_server
    BEFORE INSERT OR UPDATE OF guild_id, character_id ON guild_memberships
    FOR EACH ROW EXECUTE FUNCTION check_guild_membership_server();

-- ---------------------------------------------------------------------
--  5. Indexes for foreign keys and frequent lookups
-- ---------------------------------------------------------------------
-- (server_id, name) on characters and guilds is already covered by UNIQUE constraints.
CREATE INDEX idx_characters_account          ON characters (account_id);
CREATE INDEX idx_characters_class            ON characters (class_id);
CREATE INDEX idx_class_abilities_ability     ON class_abilities (ability_id);
CREATE INDEX idx_character_abilities_ability ON character_abilities (ability_id);
CREATE INDEX idx_guild_memberships_active    ON guild_memberships (guild_id) WHERE left_at IS NULL;

COMMIT;
