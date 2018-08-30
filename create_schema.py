# create schema for gtfs data
import os
import pandas as pd
import config as c
from sqlalchemy import create_engine

engine = create_engine('{}://{}:{}@{}:{}/{}'.format(
    c.DB_TYPE,
    c.USER_NAME,
    c.USER_PASSWORD,
    c.DB_ADDRESS,
    c.PORT_NUMBER,
    c.DATABASE_NAME,
))

os.chdir('data/')

for dir in os.listdir():
    for file in os.listdir(dir):
        table_name = file.split('.')[0]
        df = pd.read_csv(os.path.join(os.getcwd(), dir, file))
        df.to_sql(table_name, engine, c.SCHEMA_NAME)
