# README #

This is a collection of perl scripts that will hopefully become something great one day.

### Notes ###

Blizzard API documentation is [here](https://github.com/Blizzard/api-wow-docs#character-profile-api)

UPDATE: Blizzard has a new API and website - [dev.battle.net](http://dev.battle.net). Apparently there aren't any new features yet, but you can sign up for an API key and get a higher limit on requests per day.

We are stealing character census data from [wow.realmpop.com](http://wow.realmpop.com/us.html) but any other sources of info would be good

Look at table partitioning in postgres - thanks aidan - http://www.postgresql.org/docs/9.1/static/ddl-partitioning.html

### TODO LIST ###

Functionality:

* Save recipe-character data in database
* Mark characters as dormant/deleted etc
* Need to figure out what information should be stored in the database - schema review


Secondary goals:

* Efficiency needs to be improved - parsing json is quick, database access is slow, API access is very slow.

* add compatibility stuff for other SQL DBs? I'm using postgres for personal preference/it was already installed on this VM.

* move functions out into module, fix up bad coding practice, etc.

Database speed can be improved by following this guide - [Tuning your Postgres Server](https://wiki.postgresql.org/wiki/Tuning_Your_PostgreSQL_Server). I was able to get 20k rows inserted per second running on a dedicated server, and about 15k rows/second on a VM at home.

### How do I get set up? ###

* Install perl, any perl dependencies, and postgresql
* Use armory.sql to configure and set up the database (you'll have to make the database and user first)
* Run realmpop_scrape.pl to grab data out of wow.realmpop.com and store it in the database
* run api_grabber.pl to use the grabbed data to start querying the blizzard API

### Dependencies ###

* LWP
* File::Slurp
* DBI and DBD::Pg
* JSON and JSON::XS