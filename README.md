# Tools for working with PostGIS
This repository contains various tool for data import and data processing in
PostGIS.

## Steps to import GTFS Data into PostGIS
1. Create a data directory in the root directory
2. Copy over GTFS data into the data as a subdirectory, the import can handle
 multiple sub-directory.
3. Configure the config.py to input desire environment variable.
    - DB_TYPE = 'postgresql'
    - USER_NAME = user name to the db
    - USER_PASSWORD = password to the db
    - DB_ADDRESS = db address
    - PORT_NUMBER = port number
    - DATABASE_NAME = name of db
    - SCHEMA_NAME = Schema name in the database
4. Run the script to import csv into PostGIS


## Steps to process the GTFS data for Cube modeling
1. Replace the schema name in the sq
2. Import the nodes that will be used in cube modeling
3. Copy and paste the sql from gtfs-process.sql into the Query Tool and Run
