drop table char_recipe;
drop table characters;
drop table recipes;
drop table guilds;

create table characters (
    char_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    realm TEXT NOT NULL,
    faction char(1) NOT NULL,
    UNIQUE (name, realm)
    );

create table recipes (
    recipe_id int PRIMARY KEY,
    name TEXT NOT NULL,
    bop boolean NOT NULL
    );

create table char_recipe (
    char_id integer references characters(char_id),
    recipe_id integer references recipes(recipe_id),
    PRIMARY KEY (char_id, recipe_id)
    );

create table guilds (
    name TEXT NOT NULL,
    realm TEXT NOT NULL,
    PRIMARY KEY (name, realm)
    );

\q
