-- =====================================================================
--  bmtsu_MMORPG — demo data
--  Run after schema.sql:  psql -d mmorpg -f schema.sql -f seed.sql
-- =====================================================================

BEGIN;

INSERT INTO servers (name, region, is_pvp_enabled) VALUES
    ('Aurora',   'EU', FALSE),   -- 1
    ('Nightfall','EU', TRUE);    -- 2

INSERT INTO character_classes (class_name) VALUES
    ('Warrior'),  -- 1
    ('Mage'),     -- 2
    ('Priest');   -- 3

INSERT INTO abilities (ability_name) VALUES
    ('Shield Bash'),  -- 1
    ('Whirlwind'),    -- 2
    ('Fireball'),     -- 3
    ('Frost Nova'),   -- 4
    ('Heal'),         -- 5
    ('Resurrection'); -- 6

INSERT INTO class_abilities (class_id, ability_id) VALUES
    (1, 1), (1, 2),          -- Warrior
    (2, 3), (2, 4),          -- Mage
    (3, 5), (3, 6), (2, 5);  -- Priest; mages can also learn Heal

INSERT INTO accounts (email, username, password_hash) VALUES
    ('alice@example.com', 'alice', '$2b$12$demo.hash.alice'),  -- 1
    ('bob@example.com',   'bob',   '$2b$12$demo.hash.bob'),    -- 2
    ('carol@example.com', 'carol', '$2b$12$demo.hash.carol');  -- 3

INSERT INTO characters (account_id, server_id, class_id, name) VALUES
    (1, 1, 1, 'Ironwall'),   -- 1  alice, Aurora, Warrior
    (1, 2, 2, 'Pyra'),       -- 2  alice, Nightfall, Mage
    (2, 1, 3, 'Lumen'),      -- 3  bob, Aurora, Priest
    (3, 1, 2, 'Frostbite');  -- 4  carol, Aurora, Mage

INSERT INTO character_progress (character_id, level, experience, balance_copper) VALUES
    (1, 42, 1250000, 1534299),   -- 153g 42s 99c
    (2, 17,   98000,   20550),
    (3, 38,  990000,  870000),
    (4, 55, 2400000, 4012345);

INSERT INTO character_state (character_id, current_health, current_mana, is_online) VALUES
    (1, 3800,  200, TRUE),
    (2,  900, 1400, FALSE),
    (3, 2100, 3000, TRUE),
    (4, 2600, 4200, FALSE);

INSERT INTO character_abilities (character_id, ability_id, ability_level) VALUES
    (1, 1, 5), (1, 2, 3),
    (2, 3, 2),
    (3, 5, 7), (3, 6, 4),
    (4, 3, 9), (4, 4, 6), (4, 5, 2);

INSERT INTO guilds (server_id, name, tag, motd) VALUES
    (1, 'Dawn Keepers', 'DAWN', 'Raid on Friday 20:00!');  -- 1

INSERT INTO guild_memberships (guild_id, character_id, rank_code, joined_at, left_at) VALUES
    (1, 1, 'leader',  now() - interval '90 days', NULL),
    (1, 3, 'officer', now() - interval '60 days', NULL),
    -- Frostbite left the guild and later came back: history is kept
    (1, 4, 'member',  now() - interval '50 days', now() - interval '20 days'),
    (1, 4, 'member',  now() - interval '5 days',  NULL);

COMMIT;
