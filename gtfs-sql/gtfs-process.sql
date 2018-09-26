-- CUBE MODELING DATA PROCESSING
-- This script uses GTFS Data to calculate head time for peak hour, head time
-- for non-peak hour, run-time, speed, and the stop and non-stop nodes that
-- the route goes through

-- Before running the script, the schema in PostGIS should contain all the GTFS
-- tables in the standard gtfs file format

-- The script will output a table with the routes and its attribute

-- STEP 1: Determine the common routes for the GTFS files
-- Method: Filtering routes that has more than 8 services, filtering out
-- that runs in the weekend and evening
-- The common route view is the base for all the calculation that follows
-- TODO: use a date filtering method for filtering out weekends services.

DROP VIEW IF EXISTS gtfs_2015.common_routes CASCADE;
CREATE OR REPLACE VIEW gtfs_2015.common_routes AS
SELECT r.route_id,
	r.route_short_name,
	t.direction_id,
	count(t.service_id) AS service_count
FROM gtfs_2015.routes r
	JOIN gtfs_2015.trips t
		ON t.route_id = r.route_id and
        (r.route_id NOT LIKE '%SATURDAY' AND
        r.route_id NOT LIKE '%SUNDAY' AND
        r.route_id NOT LIKE '%WEEKEND' AND
        r.route_id NOT LIKE '%EVENING' AND
        r.route_id NOT LIKE '%NIGHT' AND
        r.route_id NOT LIKE '%PM' AND
		r.route_id NOT LIKE '%LIMITED')
GROUP BY r.route_id, t.direction_id, r.route_short_name HAVING count(t.service_id) > 8;

-- STEP 2: Calculate head-time for peak hour
-- Assumption: Peak hour is 06:00-08:59, trips 'NO' are filtered out for these
-- routes run on no-school day
-- Method: For all the common routes with direction, from the stop_times table
-- get all the time between the peak hour for the first stop in the sequence.
-- Then find the average time between each trip.
-- Example: AirBus 06:16:00, Airbus 07:02:00, the head time would be 00:46:00,
-- If there is only one trip during the period, the head time is assigned
-- to 02:59:00

-- Create view for head-time during peak hours 06-07-08
DROP VIEW IF EXISTS gtfs_2015.peak_headway;
CREATE OR REPLACE VIEW gtfs_2015.peak_headway AS
SELECT v.route_id,
	v.direction_id,
	CASE WHEN count(v.arrival_time) = 1 THEN '02:59:00'
	ELSE (max(v.arrival_time) - min(v.arrival_time)) / (count(v.arrival_time) - 1)
	END
	AS head_time
FROM (
	SELECT DISTINCT ON (routes.route_id, stop_times.arrival_time)
	    routes.route_id,
		trips.direction_id,
	    stop_times.arrival_time::interval
	FROM gtfs_2015.stop_times AS stop_times
	JOIN gtfs_2015.trips AS trips
	    ON stop_times.trip_id = trips.trip_id
	RIGHT OUTER JOIN gtfs_2015.common_routes AS routes
	    ON
	        routes.route_id = trips.route_id
	WHERE (stop_times.arrival_time LIKE '06%'
			OR stop_times.arrival_time LIKE '07%'
		  	OR stop_times.arrival_time LIKE '08%')
	        AND stop_times.stop_sequence = 1
			AND stop_times.trip_id NOT LIKE '%NO%'
) AS v
GROUP BY v.route_id, v.direction_id;


-- STEP 3: Calculate head-time for non-peak hour
-- Assumption: Non-peak hour is 14:00-16:59, trips 'NO' are filtered out for
-- these routes run on no-school day
-- Method: For all the common routes with direction, from the stop_times table
-- get all the time between the peak hour for the first stop in the sequence.
-- Then find the average time between each trip.
-- Example: AirBus 06:16:00, Airbus 07:02:00, the head time would be 00:46:00,
-- If there is only one trip during the period, the head time is assigned
-- to 02:59:00

-- Create view for head-time during non peak hour 14,15,16
DROP VIEW IF EXISTS gtfs_2015.non_peak_headway;
CREATE OR REPLACE VIEW gtfs_2015.non_peak_headway AS
SELECT v.route_id,
	v.direction_id,
	CASE WHEN count(v.arrival_time) = 1 THEN '02:59:00'
	ELSE (max(v.arrival_time) - min(v.arrival_time)) / (count(v.arrival_time) - 1)
	END
	AS head_time
FROM (
	SELECT DISTINCT ON (routes.route_id, stop_times.arrival_time)
	    routes.route_id,
		trips.direction_id,
	    stop_times.arrival_time::interval
	FROM gtfs_2015.stop_times AS stop_times
	JOIN gtfs_2015.trips AS trips
	    ON stop_times.trip_id = trips.trip_id
	RIGHT OUTER JOIN gtfs_2015.common_routes AS routes
	    ON
	        routes.route_id = trips.route_id
	WHERE (stop_times.arrival_time LIKE '14%'
			OR stop_times.arrival_time LIKE '15%'
		  	OR stop_times.arrival_time LIKE '16%')
	        AND stop_times.stop_sequence = 1
			AND stop_times.trip_id NOT LIKE '%NO%'
) AS v
GROUP BY v.route_id, v.direction_id;

-- STEP 4: Find the run time for each common route
-- Method: For all the trips that happened between the peak and non-peak hours,
-- find the run time for each one, and the average is taken for all the trips
-- Assumption: Trips that are shorter than 5 mins are ignored.
DROP VIEW IF EXISTS gtfs_2015.run_time;
CREATE OR REPLACE VIEW gtfs_2015.run_time AS
WITH run_time AS (
    SELECT
        routes.route_id,
		trips.direction_id,
    	max(arrival_time::interval) - min(arrival_time::interval) AS run_time
    FROM gtfs_2015.stop_times AS stop_times
    JOIN gtfs_2015.trips AS trips
        ON trips.trip_id = stop_times.trip_id
    RIGHT OUTER JOIN gtfs_2015.common_routes AS routes
        ON routes.route_id = trips.route_id
	WHERE (stop_times.arrival_time LIKE '%14'
		OR stop_times.arrival_time LIKE '15%'
		OR stop_times.arrival_time LIKE '16%'
		OR stop_times.arrival_time LIKE '06%'
		OR stop_times.arrival_time LIKE '07%'
		OR stop_times.arrival_time LIKE '08%')
    GROUP BY routes.route_id, trips.trip_id, trips.direction_id
    HAVING max(arrival_time::interval) - min(arrival_time::interval) > '00:05:00'
)
SELECT route_id, direction_id, avg(run_time)
FROM run_time
GROUP BY route_id, direction_id;


-- STEP 5: Find the distance traveled for each route
-- Method: Find the distance for all trips that are part of the common route
-- and take the average distance for all the trips
-- Assumption: include all peak hour and non-peak hour trips
-- TODO: write a more efficient query to filter out trips before average dist

CREATE INDEX shapes_shape_id_index
	ON gtfs_2015.shapes(shape_id);
CREATE INDEX trips_shape_id_index
	ON gtfs_2015.trips(shape_id);
CREATE INDEX trips_trip_id_index
	ON gtfs_2015.trips(trip_id);
CREATE INDEX stop_times_trip_id_index
	ON gtfs_2015.stop_times(trip_id);

DROP MATERIALIZED VIEW gtfs_2015.dist_travel;
CREATE MATERIALIZED VIEW gtfs_2015.dist_travel AS (
    SELECT
		routes.route_id,
		trips.direction_id,
		avg(shape_dist_traveled) AS dist_travel
    FROM gtfs_2015.shapes AS shapes
    JOIN gtfs_2015.trips AS trips
        ON trips.shape_id = shapes.shape_id
    RIGHT OUTER JOIN gtfs_2015.stop_times AS stop_times
        ON stop_times.trip_id = trips.trip_id
            AND (stop_times.arrival_time LIKE '%14'
                OR stop_times.arrival_time LIKE '15%'
                OR stop_times.arrival_time LIKE '16%'
                OR stop_times.arrival_time LIKE '06%'
        		OR stop_times.arrival_time LIKE '07%'
        	  	OR stop_times.arrival_time LIKE '08%')
    RIGHT OUTER JOIN gtfs_2015.common_routes AS routes
        ON routes.route_id = trips.route_id
    GROUP BY routes.route_id, trips.direction_id
);
------------------------------------------------------

-- STEP 6: Create functions to calculate speed and interval conversion
-- Create a function to calculate speed (dist, ttime)
-- Speed = distance / time
-- return float
CREATE OR REPLACE FUNCTION calc_speed(dist float, ttime float) RETURNS float
AS $$
	BEGIN
		RETURN dist / ttime;
	END;
$$
LANGUAGE plpgsql
IMMUTABLE
RETURNS NULL ON NULL INPUT;

-- Function to convert interval into decimal hours
-- conv_inter_float(interval)
-- return float
CREATE OR REPLACE FUNCTION conv_inter_float(inter interval) RETURNS float
AS $$
	BEGIN
		RETURN EXTRACT (HOUR FROM inter) + (EXTRACT (MINUTE FROM inter) / 60) + (EXTRACT (SECOND FROM inter) / 3600);
	END;
$$
LANGUAGE plpgsql
IMMUTABLE
RETURNS NULL ON NULL INPUT;

-- Function to convert interval into minutes
-- inter_to_min(interval)
-- return int
CREATE OR REPLACE FUNCTION inter_to_min(inter interval) RETURNS int
AS $$
	BEGIN
		RETURN (EXTRACT (HOUR FROM inter) * 60) + EXTRACT (MINUTE FROM inter);
	END;
$$
LANGUAGE plpgsql
IMMUTABLE
RETURNS NULL ON NULL INPUT;

-- STEP 7: Calculate speed for each route
-- Method: Divide the average dist travel for each route by the average time
-- for each route
-- Create XY speed based on distance travel and run_time
DROP VIEW IF EXISTS gtfs_2015.xy_speed;
CREATE VIEW gtfs_2015.xy_speed AS
SELECT dist_travel.route_id,
	dist_travel.direction_id,
   	calc_speed(dist_travel.dist_travel * 0.00062137, conv_inter_float(run_time.avg)) AS xy_speed
FROM gtfs_2015.dist_travel AS dist_travel
    JOIN gtfs_2015.run_time AS run_time
        ON dist_travel.route_id = run_time.route_id AND
			dist_travel.direction_id = run_time.direction_id;


-- STEP 8: Add geometry column for the nodes, shapes, and stops  to be used in
-- later calculation
-- add geometry to cube nodes
SELECT AddGeometryColumn('gtfs_2015', 'cube_nodes', 'geom', 3435, 'POINT', 2);
UPDATE gtfs_2015.cube_nodes SET geom = ST_SetSRID(ST_MakePoint(x, y), 3435);

-- add geometry for stops
-- transform from 4326 to 3435
SELECT AddGeometryColumn('gtfs_2015', 'stops', 'geom', 3435, 'POINT', 2);
UPDATE gtfs_2015.stops SET geom = ST_Transform(ST_SetSRID(ST_MakePoint(stop_lon, stop_lat), 4326), 3435);

-- add geometry for shapes
-- transform from 4326 to 3435
SELECT AddGeometryColumn('gtfs_2015', 'shapes', 'geom', 3435, 'POINT', 2);
UPDATE gtfs_2015.shapes SET geom = ST_Transform(ST_SetSRID(ST_MakePoint(shape_pt_lon, shape_pt_lat), 4326), 3435);

-- Create spatial index
CREATE INDEX shapes_geom_index
	ON gtfs_2015.shapes
	USING gist(geom);

CREATE INDEX cube_nodes_geom_index
	ON gtfs_2015.cube_nodes
	USING gist(geom);

-- STEP 9: Determine if the route is circular
-- Method: For each route and direction, find the first node and the last node
-- of the route to determine if thaty are within 3000 feet of each other
-- TODO: Simplify the query
DROP VIEW IF EXISTS gtfs_2015.route_view;
CREATE OR REPLACE VIEW gtfs_2015.route_view AS
WITH route_query AS (
	SELECT
		t.route_id,
		t.shape_id,
		t.direction_id,
		COUNT(t.shape_id) AS shape_count
	FROM gtfs_2015.trips t
		RIGHT OUTER JOIN gtfs_2015.common_routes cr
			ON cr.route_id = t.route_id
	GROUP BY t.route_id, t.shape_id, t.direction_id
	ORDER BY t.route_id
)
SELECT ori.route_id, ori.direction_id, ori.shape_id, max(ori.shape_count) AS max_count
FROM route_query ori
GROUP BY ori.route_id, ori.direction_id, ori.shape_id
ORDER BY ori.route_id;

DROP VIEW IF EXISTS gtfs_2015.route_direction_shape CASCADE;
CREATE VIEW gtfs_2015.route_direction_shape AS
SELECT rv.route_id, rv.direction_id, tem.shape_id FROM gtfs_2015.route_view rv
	JOIN (
		SELECT
			t.route_id,
			t.shape_id,
			t.direction_id,
			count(t.shape_id) AS shape_count
		FROM gtfs_2015.trips t
			RIGHT OUTER JOIN gtfs_2015.common_routes cr
				ON cr.route_id = t.route_id
		GROUP BY t.route_id, t.shape_id, t.direction_id
		ORDER BY t.route_id
	) tem
	ON tem.route_id = rv.route_id AND
		tem.direction_id = rv.direction_id AND
		tem.shape_count = rv.max_count;

-- Find the cube nodes that the routes goes through
DROP VIEW IF EXISTS gtfs_2015.cube_route_nodes;
CREATE MATERIALIZED VIEW gtfs_2015.cube_route_nodes AS
SELECT rds.route_id,
	rds.direction_id,
	rds.shape_id,
	min(shapes.shape_pt_sequence) seq,
	cube_nodes.n
FROM gtfs_2015.route_direction_shape rds
	JOIN gtfs_2015.shapes shapes
		ON shapes.shape_id = rds.shape_id
	RIGHT OUTER JOIN gtfs_2015.cube_nodes AS cube_nodes
		ON ST_DWithin(shapes.geom, cube_nodes.geom, 40)
GROUP BY rds.route_id, rds.direction_id, rds.shape_id, cube_nodes.n;

DROP VIEW IF EXISTS gtfs_2015.circular_route;
CREATE OR REPLACE VIEW gtfs_2015.circular_route AS
SELECT vv.route_id,
	vv.direction_id,
	ST_DWithin(vv.first_n, vv.last_n, 3000) AS circular_route
FROM (
	SELECT v.route_id,
		v.direction_id,
		first_n.geom AS first_n,
		last_n.geom AS last_n
	FROM (
		SELECT route_id,
			direction_id,
			seq,
			n,
			first_value(n) OVER (
				PARTITION BY route_id, direction_id
				ORDER BY seq
			) AS f,
			last_value(n) OVER (
				PARTITION BY route_id, direction_id
			) AS l
		FROM gtfs_2015.cube_route_nodes
		ORDER BY route_id, direction_id, seq
	) AS v
	JOIN gtfs_2015.cube_nodes first_n
		ON v.f = first_n.n
	JOIN gtfs_2015.cube_nodes last_n
		ON v.l = last_n.n
	WHERE v.route_id IS NOT NULL
	GROUP BY v.route_id, v.direction_id, first_n.geom, last_n.geom
) AS vv;


-- STEP 10: Create a view that match the cube
-- Create the view for stop_id matching the cube nodes id
-- Method: Find the closet matching node to the bus stop
DROP VIEW IF EXISTS gtfs_2015.stop_cube_node;
CREATE OR REPLACE VIEW gtfs_2015.stop_cube_node AS
SELECT s.stop_id,
  (SELECT cn.n
   FROM gtfs_2015.cube_nodes as cn
   ORDER BY s.geom <#> cn.geom LIMIT 1) AS cube_node_id
FROM gtfs_2015.stops AS s;

-- STEP 11: Find the stops that each route goes through
-- Method: Select a trip with the longest shape to represent the route (exclude
-- some abnormal trips), then using the stops for that trip to find all the
-- nodes that the trip stop at.  Aggregate all the stop nodes into a string.
DROP VIEW IF EXISTS gtfs_2015.stop_string;
CREATE OR REPLACE VIEW gtfs_2015.stop_string AS
SELECT
	sorted_intersection.route_id,
	sorted_intersection.direction_id,
	sorted_intersection.shape_id,
	string_agg(sorted_intersection.intersection_id::text, ', ') AS stop_nodes
FROM
	(
		SELECT uni.route_id, uni.direction_id, uni.shape_id, uni.cube_node_id AS intersection_id
		FROM (
			SELECT DISTINCT ON (stops.route_id, stops.direction_id, stops.cube_node_id, stops.shape_id) *
			FROM (
				SELECT
					rep_trip.route_id,
					rep_trip.direction_id,
					scn.cube_node_id,
					rep_trip.shape_id,
					stop_sequence
				FROM (
					SELECT DISTINCT ON (common_routes.route_id, common_routes.direction_id)
						common_routes.route_id,
						common_routes.direction_id,
						trips.trip_id,
						trips.shape_id,
						line_length.lin AS line_len
					FROM gtfs_2015.common_routes AS common_routes
					JOIN gtfs_2015.trips AS trips
						ON trips.route_id = common_routes.route_id AND
						trips.direction_id = common_routes.direction_id
					JOIN (
						SELECT v.shape_id,
							ST_Length(ST_MakeLine(v.pt)) AS lin
						FROM (
							SELECT
								shapes.shape_id,
								shapes.geom AS pt
							FROM gtfs_2015.shapes AS shapes
							ORDER BY shapes.shape_id, shapes.shape_pt_sequence
						) AS v
						GROUP BY v.shape_id
					) AS line_length
						ON line_length.shape_id = trips.shape_id
					WHERE trip_id NOT LIKE '%NO%' AND
						trip_id <> '[@14.0.51709152@][3][1278100832750]/0__G5_MF' AND
						trip_id <> '[@2.0.80545657@][31][1433171304976]/0__7E_SHOW#1_WED' AND
						trip_id <> '[@36.0.28511750@][1][1175200064861]/1__3N#3_SHOW' AND
						trip_id <> '[@14.0.56289853@][1][1313082941180]/0__GN3_SCHMF' AND
						trip_id <> '[@14.0.56289853@][2][1314643979349]/0__SV4_SCH_WED' AND
						trip_id <> '[@36.0.28511750@][1][1175200064861]/1__3N#3_SHOW_WED' AND
						trip_id <> '[@36.0.28511750@][2][1175200035939]/0__SV4_SCHUIMF' AND
						trip_id <> '[@2.0.80545657@][31][1433171304976]/0__7E/5E_SHOW_SCH'
					ORDER BY
						common_routes.route_id,
						common_routes.direction_id,
						line_length.lin DESC
				) rep_trip
				JOIN gtfs_2015.stop_times AS stop_times
					ON stop_times.trip_id = rep_trip.trip_id
				JOIN gtfs_2015.stop_cube_node AS scn
					ON scn.stop_id = stop_times.stop_id
				ORDER BY route_id, direction_id, stop_sequence
			) AS stops
		) AS uni
		ORDER BY route_id, direction_id, stop_sequence
	) AS sorted_intersection
GROUP BY sorted_intersection.route_id, sorted_intersection.direction_id, sorted_intersection.shape_id;

-- STEP 12: Find all the stop and non-stop nodes
-- Method: For all the points the shape goes through, match it to the cube nodes
-- if its within 40 feet. Aggregating all the unique nodes together and check
-- to see if they are part of the stop nodes, positive for stop nodes and
-- negative for non-stop nodes
DROP VIEW IF EXISTS gtfs_2015.cube_node_string;
CREATE OR REPLACE VIEW gtfs_2015.cube_node_string AS
SELECT
	seq_node.route_id,
	seq_node.direction_id,
	string_agg(
	CASE WHEN seq_node.stop_nodes LIKE '%' || seq_node.n::text || '%' THEN seq_node.n::text
	ELSE (-seq_node.n)::text
	END, ', '
	)
FROM (
	SELECT stop_string.route_id,
		stop_string.direction_id,
		stop_string.stop_nodes,
		cube_nodes.n,
		min(shapes.shape_pt_sequence) AS seq
	FROM gtfs_2015.stop_string AS stop_string
	JOIN gtfs_2015.shapes shapes
		ON shapes.shape_id = stop_string.shape_id
	RIGHT OUTER JOIN gtfs_2015.cube_nodes AS cube_nodes
		ON ST_DWithin(shapes.geom, cube_nodes.geom, 40)
	GROUP BY stop_string.route_id, stop_string.stop_nodes, stop_string.direction_id, cube_nodes.n
	ORDER BY route_id, direction_id, seq) AS seq_node
GROUP BY seq_node.route_id,
	seq_node.direction_id;


-- STEP 13: Join all the previous view to create final output
-- Method: Join based on route_id and direction_id, and perform formatting
SELECT
	'LINE NAME="' || common_routes.route_id || '"' AS line_name,
	'LONGNAME="' || common_routes.route_id || '-' || common_routes.route_short_name || '-' || common_routes.direction_id || '"' AS long_name,
	'MODE=' || 1 AS mode,
	'OPERATOR=' || 1 AS operator,
	'VEHICLETYPE=' || 1 AS vehicle_type,
	'ONEWAY=T' AS one_way,
	'CIRCULAR=' || CASE WHEN circular_route.circular_route = 'True' Then 'T'
	ELSE 'F'
	END
	AS circular_route,
	'HEADWAY[1]=' || CASE WHEN inter_to_min(hw_peak.head_time) IS NULL THEN 999
	ELSE inter_to_min(hw_peak.head_time)
	END
	AS headway_1,
	'HEADWAY_R[1]=' || CASE WHEN inter_to_min(hw_non_peak.head_time) IS NULL THEN 999
	ELSE inter_to_min(hw_non_peak.head_time)
	END
	AS headway_2,
	'RUNTIME=' || inter_to_min(run_time.avg) AS run_time,
	'XYSPEED=' || round(xy_speed.xy_speed::numeric, 0) AS xy_speed,
	'N=' || node_string.string_agg AS n
FROM gtfs_2015.common_routes AS common_routes
LEFT OUTER JOIN gtfs_2015.peak_headway AS hw_peak
	ON hw_peak.route_id = common_routes.route_id AND
		hw_peak.direction_id = common_routes.direction_id
LEFT OUTER JOIN gtfs_2015.non_peak_headway AS hw_non_peak
	ON hw_non_peak.route_id = common_routes.route_id AND
		hw_non_peak.direction_id = common_routes.direction_id
JOIN gtfs_2015.circular_route AS circular_route
	ON circular_route.route_id = common_routes.route_id AND
		circular_route.direction_id = common_routes.direction_id
JOIN gtfs_2015.run_time AS run_time
	ON run_time.route_id = common_routes.route_id AND
		run_time.direction_id = common_routes.direction_id
JOIN gtfs_2015.xy_speed AS xy_speed
	ON xy_speed.route_id = common_routes.route_id AND
		xy_speed.direction_id = common_routes.direction_id
JOIN gtfs_2015.cube_node_string as node_string
	ON node_string.route_id = common_routes.route_id AND
		node_string.direction_id = common_routes.direction_id
ORDER BY common_routes.route_id;

--------------------------------------------------------------------------------
-- Extract SQL Quotes for other method of finding nodes

-- Select the cube_nodes based on gtfs shape data
-- CREATE MATERIALIZED VIEW gtfs_2015.cube_route_nodes AS
-- SELECT shape_id, min(shape_pt_sequence), cn.n
-- FROM gtfs_2015.shapes AS s
-- 	JOIN gtfs_2015.common_routes as
-- 	RIGHT OUTER JOIN gtfs_2015.cube_nodes AS cn
-- 		ON ST_DWithin(s.geom, cn.geom, 30)
-- GROUP BY s.shape_id, cn.n
-- ORDER BY min(shape_pt_sequence);


-- Find the most common shapes for each route with direction
-- WITH route_query AS (
-- 	SELECT
-- 		t.route_id,
-- 		t.shape_id,
-- 		t.direction_id,
-- 		count(t.shape_id) AS shape_count
-- 	FROM gtfs_2015.trips t
-- 		RIGHT OUTER JOIN gtfs_2015.common_routes_mat cr
-- 			ON cr.route_id = t.route_id
-- 	GROUP BY t.route_id, t.shape_id, t.direction_id
-- 	ORDER BY t.route_id
-- )
-- SELECT ori.route_id, ori.direction_id, max(ori.shape_count) AS max_count
-- FROM route_query ori
-- GROUP BY ori.route_id, ori.direction_id
-- ORDER BY ori.route_id;

-- DROP VIEW gtfs_2015.route_view;
-- CREATE OR REPLACE VIEW gtfs_2015.route_view AS
-- WITH route_query AS (
-- 	SELECT
-- 		t.route_id,
-- 		t.shape_id,
-- 		t.direction_id,
-- 		COUNT(t.shape_id) AS shape_count
-- 	FROM gtfs_2015.trips t
-- 		RIGHT OUTER JOIN gtfs_2015.common_routes cr
-- 			ON cr.route_id = t.route_id
-- 	GROUP BY t.route_id, t.shape_id, t.direction_id
-- 	ORDER BY t.route_id
-- )
-- SELECT ori.route_id, ori.direction_id, ori.shape_id, max(ori.shape_count) AS max_count
-- FROM route_query ori
-- GROUP BY ori.route_id, ori.direction_id, ori.shape_id
-- ORDER BY ori.route_id;
--
-- DROP VIEW gtfs_2015.route_direction_shape CASCADE;
-- CREATE VIEW gtfs_2015.route_direction_shape AS
-- SELECT rv.route_id, rv.direction_id, tem.shape_id FROM gtfs_2015.route_view rv
-- 	JOIN (
-- 		SELECT
-- 			t.route_id,
-- 			t.shape_id,
-- 			t.direction_id,
-- 			count(t.shape_id) AS shape_count
-- 		FROM gtfs_2015.trips t
-- 			RIGHT OUTER JOIN gtfs_2015.common_routes cr
-- 				ON cr.route_id = t.route_id
-- 		GROUP BY t.route_id, t.shape_id, t.direction_id
-- 		ORDER BY t.route_id
-- 	) tem
-- 	ON tem.route_id = rv.route_id AND
-- 		tem.direction_id = rv.direction_id AND
-- 		tem.shape_count = rv.max_count

-- Create a better algorithm to match the shape to the cube nodes
-- SELECT
-- 	l.route_id,
-- 	l.direction_id,
-- 	cube_nodes.id,
-- 	ST_LineLocatePoint(l.shape_line, cube_nodes.geom) AS pt_location
-- FROM (
-- 	SELECT rds.route_id,
-- 		rds.direction_id,
-- 		ST_MakeLine(shapes.geom) AS shape_line
-- 	FROM gtfs_2015.route_direction_shape rds
-- 		JOIN gtfs_2015.shapes shapes
-- 			ON shapes.shape_id = rds.shape_id
-- 	GROUP BY rds.route_id,
-- 		rds.direction_id,
-- 		shapes.shape_pt_sequence
-- 	ORDER BY shapes.shape_pt_sequence
-- ) AS l
-- JOIN gtfs_2015.cube_nodes AS cube_nodes
-- 	ON ST_DWithin(l.shape_line, cube_nodes.geom, 30)
-- ORDER BY l.route_id, l.direction_id, ST_LineLocatePoint(l.shape_line, cube_nodes.geom)







-- Aggregate the stops into strings while also find stop and non stop nodes
-- CREATE OR REPLACE VIEW gtfs_2015.cube_node_string AS
-- SELECT
-- 	sorted_intersection.route_id,
-- 	sorted_intersection.direction_id,
-- 	string_agg(sorted_intersection.intersection_id, ', ') AS nodes_agg
-- FROM
-- 	(SELECT
-- 		route_id,
-- 		direction_id,
-- 		seq,
-- 		CASE WHEN (n IN (SELECT cube_node_id FROM gtfs_2015.stop_cube_node)) THEN n::text
-- 		ELSE (-n)::text
-- 		END AS intersection_id
-- 	FROM gtfs_2015.cube_route_nodes
-- 	ORDER BY route_id, direction_id, seq) AS sorted_intersection
-- GROUP BY sorted_intersection.route_id, sorted_intersection.direction_id

-- Create a better way to find stop and non-stop nodes
-- based on most commmon service
-- CREATE VIEW gtfs_2015.route_common_service AS
-- SELECT DISTINCT ON (route_id, direction_id)
-- 	v.route_id,
-- 	v.direction_id,
-- 	v.service_id,
-- 	v.service_count
-- FROM (
-- 	SELECT
-- 		common_routes.route_id,
-- 		common_routes.direction_id,
-- 		trips.service_id,
-- 		COUNT(trips.service_id) as service_count
-- 	FROM gtfs_2015.common_routes AS common_routes
-- 	JOIN gtfs_2015.trips AS trips
-- 		ON trips.route_id = common_routes.route_id
-- 	GROUP BY common_routes.route_id,
-- 		common_routes.direction_id,
-- 		trips.service_id
-- 	ORDER BY common_routes.route_id
-- ) AS v
-- ORDER BY v.route_id, v.direction_id, v.service_count DESC
--
-- SELECT rep_trip.route_id,
-- 	rep_trip.direction_id,
-- 	scn.cube_node_id
-- FROM (
-- 	SELECT DISTINCT ON (route_id, direction_id)
-- 		route.route_id,
-- 		route.direction_id,
-- 		trips.trip_id
-- 	FROM gtfs_2015.route_common_service AS route
-- 	JOIN gtfs_2015.trips AS trips
-- 		ON trips.route_id = route.route_id
-- 	ORDER BY route.route_id,
-- 		route.direction_id
-- ) rep_trip
-- JOIN gtfs_2015.stop_times AS stop_times
-- 	ON stop_times.trip_id = rep_trip.trip_id
-- JOIN gtfs_2015.stop_cube_node AS scn
-- 	ON scn.stop_id = stop_times.stop_id
-- WHERE route_id = 'TEAL'
-- ORDER BY route_id, direction_id, stop_sequence
