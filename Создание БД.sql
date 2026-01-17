-- 1. Серверы
CREATE TABLE servers (
    server_id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    region VARCHAR(30) NOT NULL,
    is_pvp_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 2. Аккаунты
CREATE TABLE accounts (
    account_id SERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    username VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP,
    is_banned BOOLEAN NOT NULL DEFAULT FALSE
);

-- 3. Классы персонажей
CREATE TABLE character_classes (
    class_id SERIAL PRIMARY KEY,
    class_name VARCHAR(30) NOT NULL UNIQUE
);

-- 4. Персонажи 
CREATE TABLE characters (
    character_id SERIAL PRIMARY KEY,
    account_id INTEGER NOT NULL REFERENCES accounts(account_id) ON DELETE CASCADE,
    server_id INTEGER NOT NULL REFERENCES servers(server_id) ON DELETE RESTRICT,
    class_id INTEGER NOT NULL REFERENCES character_classes(class_id) ON DELETE RESTRICT,
    name VARCHAR(30) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(server_id, name)
);

-- 5. Прогресс персонажа
CREATE TABLE character_progress (
    character_id INTEGER PRIMARY KEY REFERENCES characters(character_id) ON DELETE CASCADE,
    level INTEGER NOT NULL DEFAULT 1 CHECK (level BETWEEN 1 AND 100),
    experience BIGINT NOT NULL DEFAULT 0,
    gold INTEGER NOT NULL DEFAULT 0,
    silver INTEGER DEFAULT 0,
    copper INTEGER DEFAULT 0,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 6. Состояние персонажа
CREATE TABLE character_state (
    character_id INTEGER PRIMARY KEY REFERENCES characters(character_id) ON DELETE CASCADE,
    current_health INTEGER NOT NULL DEFAULT 100,
    current_mana INTEGER NOT NULL DEFAULT 100,
    position_x REAL DEFAULT 0,
    position_y REAL DEFAULT 0,
    position_z REAL DEFAULT 0,
    is_online BOOLEAN NOT NULL DEFAULT FALSE,
    last_update TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 7. Способности (справочник)
CREATE TABLE abilities (
    ability_id SERIAL PRIMARY KEY,
    ability_name VARCHAR(30) NOT NULL UNIQUE
);

-- 8. Связь Класс-Способность
CREATE TABLE class_abilities (
    class_id INTEGER NOT NULL REFERENCES character_classes(class_id) ON DELETE CASCADE,
    ability_id INTEGER NOT NULL REFERENCES abilities(ability_id) ON DELETE CASCADE,
    PRIMARY KEY (class_id, ability_id)
);

-- 9. Способности персонажей
CREATE TABLE character_abilities (
    character_id INTEGER NOT NULL REFERENCES characters(character_id) ON DELETE CASCADE,
    ability_id INTEGER NOT NULL REFERENCES abilities(ability_id) ON DELETE CASCADE,
    level INTEGER NOT NULL DEFAULT 1 CHECK (level BETWEEN 1 AND 10),
    learned_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (character_id, ability_id)
);

--10. Гильдии 
CREATE TABLE guilds (
    guild_id SERIAL PRIMARY KEY,
    server_id INTEGER NOT NULL REFERENCES servers(server_id) ON DELETE RESTRICT,
    name VARCHAR(50) NOT NULL,
    tag VARCHAR(10) NOT NULL,
    leader_character_id INTEGER NOT NULL REFERENCES characters(character_id) ON DELETE RESTRICT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    motd TEXT,
    UNIQUE(server_id, name), -- Имя уникально на сервере
    UNIQUE(server_id, tag)   -- Тег уникален на сервере
);

-- 11. Члены гильдий
CREATE TABLE guild_members (
    membership_id SERIAL PRIMARY KEY,
    guild_id INTEGER NOT NULL REFERENCES guilds(guild_id) ON DELETE CASCADE,
    character_id INTEGER NOT NULL UNIQUE REFERENCES characters(character_id) ON DELETE CASCADE,
    rank VARCHAR(30) NOT NULL DEFAULT 'Member',
    joined_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    left_at TIMESTAMP,
    note TEXT
);


CREATE INDEX idx_characters_account ON characters(account_id);
CREATE INDEX idx_characters_server ON characters(server_id);
CREATE INDEX idx_guild_members_active ON guild_members(guild_id, left_at) WHERE left_at IS NULL;
