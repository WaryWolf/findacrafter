DROP TABLE IF EXISTS char_recipe;
DROP TABLE IF EXISTS characters;
DROP TABLE IF EXISTS recipes;
DROP TABLE IF EXISTS guilds;

CREATE TABLE characters (
    char_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    realm TEXT NOT NULL,
    faction char(1) NOT NULL,
    crafter BOOL NOT NULL,
    available BOOL NOT NULL,
    timestamp INTEGER,
    UNIQUE (name, realm)
    );

CREATE TABLE recipes (
    recipe_id INTEGER PRIMARY KEY,
    name TEXT NOT NULL
    );

CREATE TABLE char_recipe (
    char_id INTEGER REFERENCES characters(char_id),
    recipe_id INTEGER REFERENCES recipes(recipe_id),
    PRIMARY KEY (char_id, recipe_id)
    );

CREATE TABLE guilds (
    name TEXT NOT NULL,
    realm TEXT NOT NULL,
    PRIMARY KEY (name, realm)
    );

\q
