CREATE USER exampleuser WITH PASSWORD 'examplepassword';
CREATE DATABASE armory;
GRANT ALL PRIVILEGES ON DATABASE armory TO armory;
ALTER SCHEMA public OWNER TO armory;
ALTER USER armory SET log_min_messages = error;
