# README #

This is a collection of perl scripts that will hopefully become something great one day.

### Notes ###

Blizzard API documentation is [here](https://github.com/Blizzard/api-wow-docs#character-profile-api)

We are stealing character census data from [wow.realmpop.com](http://wow.realmpop.com/us.html) but any other sources of info would be good

### TODO LIST ###

Functionality:
* Save recipe-character data in database
* Mark characters as dormant/deleted etc
* Need to figure out what information should be stored in the database - schema review


Secondary goals:

* Efficiency needs to be improved - parsing json is quick, database access is slow, API access is very slow.

* add compatibility stuff for other SQL DBs? I'm using postgres for personal preference/it was already installed on this VM.

Speed can probably be improved by running on a dedicated server in the US, closer to the API servers. I will test this out shortly.

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