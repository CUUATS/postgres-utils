SELECT AddGeometryColumn('gtfs_2015', 'stops', 'geom', 3435, 'POINT', 2);
UPDATE gtfs_2015.stops SET geom = ST_Transform(ST_SetSRID(ST_MakePoint(stop_lon, stop_lat), 4326), 3435);

SELECT AddGeometryColumn('gtfs_2015', 'shapes', 'geom', 3435, 'POINT', 2);
UPDATE gtfs_2015.shapes SET geom = ST_Transform(ST_SetSRID(ST_MakePoint(shape_pt_lon, shape_pt_lat), 4326), 3435);
-- DROP COLUMN geom;

select * from gtfs_2015.stops;
select * from gtfs_2015.shapes;