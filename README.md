# README #

This is a collection of perl scripts that make use of wow.realmpop.com and Blizzard's WoW character API to generate a database of characters and any craftable items they can create. Once you have a populated database, you can query it to find out who can craft a particular item on your realm.

### NOTES ###

Blizzard API documentation is [here](https://github.com/Blizzard/api-wow-docs#character-profile-api).

UPDATE: Blizzard has a new API and website - [dev.battle.net](http://dev.battle.net). Apparently there aren't any new features yet, but you can sign up for an API key and get a higher limit on requests per day.

### FEATURES COMPLETE ###

* Grab data from realmpop's json blobs and put it into database
* Save recipe-character data in database
* Mark characters as dormant/deleted etc


### TODO LIST ###

Functionality:

* Need to figure out what information should be stored in the database - schema review

Other:

Secondary goals:

* character discovery through examining each char's guild/looking up their guild members (this could be run on another server to avoid the API limit!)

* add compatibility stuff for other SQL DBs? I'm using postgres for personal preference/it was already installed on this VM.

* move functions out into module, fix up bad coding practice, etc.

Database speed can be improved by following this guide - [Tuning your Postgres Server](https://wiki.postgresql.org/wiki/Tuning_Your_PostgreSQL_Server). I was able to get 20k rows inserted per second running on a dedicated server, and about 15k rows/second on a VM at home. UPDATE: with the new schema using split tables, inserts are up to 80k rows a second and queries seem to be instant!

"The character and guild API resources do honor HTTP requests that contain the "If-Modified-Since" header." <- put a last-checked timestamp in characters table and use that for requests to save on processing time (and be nice to the api, whom we love so much)

### How do I get set up? ###

* Install perl, any perl dependencies, and postgresql
* use init_db.sql to create the database and user, and set permissions (edit the file if you want to change the DB/user name/password, and add that user/password to conf.pl)
* use reset_db.sql to create the necessary tables (you can also run this to clear all data from the database)
* Run init_db.pl to grab data out of wow.realmpop.com and store it in the database
* run api_grabber.pl to use the grabbed data to start querying the blizzard API

### Dependencies ###

* LWP
* File::Slurp
* DBI and DBD::Pg
* JSON and JSON::XS
* Coro and Coro::LWP
