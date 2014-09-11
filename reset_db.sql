--DROP TABLE IF EXISTS char_recipe;
--DROP TABLE IF EXISTS characters;
--DROP TABLE IF EXISTS recipes;
--DROP TABLE IF EXISTS guilds;
--DROP TABLE IF EXISTS realms;

DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO public;
COMMENT ON SCHEMA public IS 'standard public schema';

CREATE TABLE realms (
    realm_id SERIAL PRIMARY KEY,
    realm TEXT NOT NULL,
    unique(realm)
    );

--CREATE TABLE characters (
--    char_id SERIAL PRIMARY KEY,
--    realm_id INTEGER REFERENCES realms(realm_id),
--    name TEXT NOT NULL,
--    faction char(1) NOT NULL,
--    crafter BOOL NOT NULL,
--    available BOOL NOT NULL,
--    timestamp INTEGER,
--    UNIQUE (name, realm_id)
--    );

CREATE TABLE recipes (
    recipe_id INTEGER PRIMARY KEY,
    name TEXT NOT NULL
    );


-- moved to init_db.pl as we are making one table per realm
--CREATE TABLE char_recipe (
--    char_id INTEGER REFERENCES characters(char_id),
--    recipe_id INTEGER REFERENCES recipes(recipe_id),
--    PRIMARY KEY (char_id, recipe_id)
--    );

CREATE TABLE guilds (
    name TEXT NOT NULL,
    realm TEXT NOT NULL,
    PRIMARY KEY (name, realm)
    );

\q
