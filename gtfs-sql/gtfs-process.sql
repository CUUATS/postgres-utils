-- Create a view for the common routes to include in query
CREATE OR REPLACE VIEW gtfs_2015.common_routes AS
SELECT r.route_id, r.route_short_name, count(t.service_id) AS service_count
FROM gtfs_2015.routes r
	JOIN gtfs_2015.trips t
		ON t.route_id = r.route_id and
        (r.route_id NOT LIKE '%SATURDAY' AND
        r.route_id NOT LIKE '%SUNDAY' AND
        r.route_id NOT LIKE '%WEEKEND' AND
        r.route_id NOT LIKE '%EVENING' AND
        r.route_id NOT LIKE '%NIGHT' AND
        r.route_id NOT LIKE '%PM')
GROUP BY r.route_id, r.route_short_name HAVING count(t.service_id) > 50;


-- Create view for head-time during peak hours 06-07-08
SELECT
    routes.route_id,
    (max(stop_times.arrival_time::interval) - min(stop_times.arrival_time::interval)) / count(stop_times.arrival_time) AS head_time
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
GROUP BY routes.route_id
HAVING (max(stop_times.arrival_time::interval) - min(stop_times.arrival_time::interval)) / count(stop_times.arrival_time) <> '00:00:00'


-- Create view for head-time during non peak hour 12, 13, 14
SELECT
    routes.route_id,
    (max(stop_times.arrival_time::interval) - min(stop_times.arrival_time::interval)) / count(stop_times.arrival_time) AS head_time
FROM gtfs_2015.stop_times AS stop_times
JOIN gtfs_2015.trips AS trips
    ON stop_times.trip_id = trips.trip_id
RIGHT OUTER JOIN gtfs_2015.common_routes AS routes
    ON
        routes.route_id = trips.route_id
WHERE (stop_times.arrival_time LIKE '12%'
		OR stop_times.arrival_time LIKE '13%'
	  	OR stop_times.arrival_time LIKE '14%')
        AND stop_times.stop_sequence = 1
GROUP BY routes.route_id
HAVING (max(stop_times.arrival_time::interval) - min(stop_times.arrival_time::interval)) / count(stop_times.arrival_time) <> '00:00:00'


-- Find the average run-time for each route base on all the trips the route has
CREATE OR REPLACE VIEW gtfs_2015.run_time AS
WITH run_time AS (
    SELECT
        routes.route_id,
    	max(arrival_time::interval) - min(arrival_time::interval) AS run_time
    FROM gtfs_2015.stop_times AS stop_times
    JOIN gtfs_2015.trips AS trips
        ON trips.trip_id = stop_times.trip_id
    RIGHT OUTER JOIN gtfs_2015.common_routes AS routes
        ON routes.route_id = trips.route_id
	WHERE (stop_times.arrival_time LIKE '%12'
		OR stop_times.arrival_time LIKE '13%'
		OR stop_times.arrival_time LIKE '14%'
		OR stop_times.arrival_time LIKE '06%'
		OR stop_times.arrival_time LIKE '07%'
		OR stop_times.arrival_time LIKE '08%')
    GROUP BY routes.route_id, trips.trip_id
    HAVING max(arrival_time::interval) - min(arrival_time::interval) > '00:05:00'
)
SELECT route_id, avg(run_time)
FROM run_time
GROUP BY route_id

-- Create a view for the distance travel for each route based on the common routes and peak and non-peak trip
CREATE OR REPLACE VIEW gtfs_2015.dist_travel AS (
    SELECT routes.route_id, avg(shape_dist_traveled) AS dist_travel
    FROM gtfs_2015.shapes AS shapes
    JOIN gtfs_2015.trips AS trips
        ON trips.shape_id = shapes.shape_id
    RIGHT OUTER JOIN gtfs_2015.stop_times AS stop_times
        ON stop_times.trip_id = trips.trip_id
            AND (stop_times.arrival_time LIKE '%12'
                OR stop_times.arrival_time LIKE '13%'
                OR stop_times.arrival_time LIKE '14%'
                OR stop_times.arrival_time LIKE '06%'
        		OR stop_times.arrival_time LIKE '07%'
        	  	OR stop_times.arrival_time LIKE '08%')
    RIGHT OUTER JOIN gtfs_2015.common_routes AS routes
        ON routes.route_id = trips.route_id
    GROUP BY routes.route_id)

CREATE OR REPLACE VIEW gtfs_2015.dist_travel AS
SELECT route_shape.route_id,
	l.shape_len
FROM gtfs_2015.route_direction_shape route_shape
JOIN (
		SELECT shape_id,
			ST_Length(ST_MakeLine(geom)) as shape_len
		FROM gtfs_2015.shapes
		GROUP BY shape_id
	) l
	ON l.shape_id = route_shape.shape_id



-- Create a function to calculate speed (dist, ttime)
CREATE OR REPLACE FUNCTION calc_speed(dist float, ttime float) RETURNS float
AS $$
	BEGIN
		RETURN dist / ttime;
	END;
$$
LANGUAGE plpgsql
IMMUTABLE
RETURNS NULL ON NULL INPUT

-- function to convert interval into decimal hours
CREATE OR REPLACE FUNCTION conv_inter_float(inter interval) RETURNS float
AS $$
	BEGIN
		RETURN EXTRACT (HOUR FROM inter) + (EXTRACT (MINUTE FROM inter) / 60) + (EXTRACT (SECOND FROM inter) / 3600);
	END;
$$
LANGUAGE plpgsql
IMMUTABLE
RETURNS NULL ON NULL INPUT

-- Create XY speed based on distance travel and run_time
CREATE MATERIALIZED VIEW gtfs_2015.xy_speed AS
SELECT dist_travel.route_id,
   calc_speed(dist_travel.dist_travel * 0.00062137, conv_inter_float(run_time.avg)) AS xy_speed
FROM gtfs_2015.dist_travel AS dist_travel
    JOIN gtfs_2015.run_time AS run_time
        ON dist_travel.route_id = run_time.route_id


-- Create the view for stop_id matching the intersection_id
-- CREATE OR REPLACE VIEW gtfs_2015.stop_intersection AS
-- SELECT s.stop_id,
--   (SELECT i.intersection_id
--    FROM street.intersection as i
--    ORDER BY s.geom <#> i.shape LIMIT 1) AS intersection_id
-- FROM gtfs_2015.stops AS s;

-- Create view for matching shape based on closet intersection
-- SELECT DISTINCT ON (intersection_id)
-- 		s.shape_id,
-- 		(SELECT
-- 		   i.intersection_id
-- 		   FROM street.intersection as i
-- 		   ORDER BY s.geom <#> i.shape LIMIT 1
-- 	   )::text AS intersection_id,
-- 	   s.shape_pt_sequence AS intersection_seq
-- 	FROM gtfs_2015.shapes AS s
-- 	WHERE s.shape_id = '100N'
--
-- -- Create the view for matching shape based on street
-- SELECT
-- 	shapes.shape_id,
-- 	(SELECT
-- 	   segment.segment_id
-- 	   FROM street.segment as segment
-- 	   ORDER BY shapes.geom <#> segment.geom LIMIT 1
--    )::text AS segment_id,
--    min(shapes.shape_pt_sequence) AS segment_sequence
-- FROM gtfs_2015.shapes AS shapes
-- WHERE shapes.shape_id = '100N'
-- GROUP BY shape_id, segment_id
-- ORDER BY segment_sequence



-- Create a list of nodes that the bus route goes through
-- If it's a bus stop, node is positive, else negative




-- Break the line down into nodes
-- CREATE VIEW gtfs_2015.shape_nodes AS
-- SELECT (st_DumpPoints((st_dump(geom)).geom)).geom AS nodes,
-- 	(st_DumpPoints((st_dump(geom)).geom)).path AS nodes_order,
-- 	(st_dump(geom)).path AS path_order
-- FROM gtfs_2015.route_2015 r
--
-- SELECT nodes, cn.id, nodes_order, path_order
-- FROM gtfs_2015.shape_nodes sn
-- 	JOIN gtfs_2015.cube_nodes cn
-- 		ON ST_DWithin(sn.nodes, cn.geom, 150)


-- Imported the nodes x, y table from cube dbf
-- Create a geom column from x,y table
SELECT AddGeometryColumn('gtfs_2015', 'cube_nodes', 'geom', 3435, 'POINT', 2);
UPDATE gtfs_2015.cube_nodes SET geom = ST_SetSRID(ST_MakePoint(x, y), 3435);

-- Create the view for stop_id matching the cube nodes id
CREATE OR REPLACE VIEW gtfs_2015.stop_cube_node AS
SELECT s.stop_id,
  (SELECT cn.id
   FROM gtfs_2015.cube_nodes as cn
   ORDER BY s.geom <#> cn.geom LIMIT 1) AS cube_node_id
FROM gtfs_2015.stops AS s;

-- Select the cube_nodes based on gtfs shape data
CREATE MATERIALIZED VIEW gtfs_2015.cube_route_nodes AS
SELECT shape_id, min(shape_pt_sequence), cn.id
FROM gtfs_2015.shapes s
	JOIN gtfs_2015.common_routes
	RIGHT OUTER JOIN gtfs_2015.cube_nodes cn
		ON ST_DWithin(s.geom, cn.geom, 30)
GROUP BY s.shape_id, cn.id
ORDER BY min(shape_pt_sequence)


-- Find the most common shapes for each route with direction
WITH route_query AS (
	SELECT
		t.route_id,
		t.shape_id,
		t.direction_id,
		count(t.shape_id) AS shape_count
	FROM gtfs_2015.trips t
		RIGHT OUTER JOIN gtfs_2015.common_routes_mat cr
			ON cr.route_id = t.route_id
	GROUP BY t.route_id, t.shape_id, t.direction_id
	ORDER BY t.route_id
)
SELECT ori.route_id, ori.direction_id, max(ori.shape_count) AS max_count
FROM route_query ori
GROUP BY ori.route_id, ori.direction_id
ORDER BY ori.route_id;DROP VIEW gtfs_2015.route_view;

CREATE OR REPLACE VIEW gtfs_2015.route_view AS
WITH route_query AS (
	SELECT
		t.route_id,
		t.shape_id,
		t.direction_id,
		count(t.shape_id) AS shape_count
	FROM gtfs_2015.trips t
		RIGHT OUTER JOIN gtfs_2015.common_routes_mat cr
			ON cr.route_id = t.route_id
	GROUP BY t.route_id, t.shape_id, t.direction_id
	ORDER BY t.route_id
)
SELECT ori.route_id, ori.direction_id, max(ori.shape_count) AS max_count
FROM route_query ori
GROUP BY ori.route_id, ori.direction_id
ORDER BY ori.route_id;

CREATE VIEW gtfs_2015.route_direction_shape AS
SELECT rv.route_id, rv.direction_id, tem.shape_id FROM gtfs_2015.route_view rv
	JOIN (
		SELECT
			t.route_id,
			t.shape_id,
			t.direction_id,
			count(t.shape_id) AS shape_count
		FROM gtfs_2015.trips t
			RIGHT OUTER JOIN gtfs_2015.common_routes_mat cr
				ON cr.route_id = t.route_id
		GROUP BY t.route_id, t.shape_id, t.direction_id
		ORDER BY t.route_id
	) tem
	ON tem.route_id = rv.route_id AND
		tem.direction_id = rv.direction_id AND
		tem.shape_count = rv.max_count


-- Find the cube nodes that the routes goes through
CREATE MATERIALIZED VIEW gtfs_2015.cube_route_nodes AS
SELECT rds.route_id,
	rds.direction_id,
	rds.shape_id,
	min(shapes.shape_pt_sequence) seq,
	cube_nodes.id
FROM gtfs_2015.route_direction_shape rds
	JOIN gtfs_2015.shapes shapes
		ON shapes.shape_id = rds.shape_id
	RIGHT OUTER JOIN gtfs_2015.cube_nodes cube_nodes
		ON ST_DWithin(shapes.geom, cube_nodes.geom, 30)
GROUP BY rds.route_id, rds.direction_id, rds.shape_id, cube_nodes.id

-- Alt: find the nodes based on a line buffer
SELECT buff.shape_id,
	cube_nodes.id
FROM (
	SELECT shape_id,
		ST_Buffer(ST_MakeLine(geom),30) AS buffer
	FROM gtfs_2015.shapes
	GROUP BY shape_id
) buff
JOIN gtfs_2015.cube_nodes AS cube_nodes
	ON ST_Contains(buff.buffer, cube_nodes.geom)
ORDER BY buff.shape_id

-- Find the stops and non-stop nodes
SELECT
	route_id,
	direction_id,
	seq,
	CASE WHEN (id IN (SELECT intersection_id FROM gtfs_2015.stop_intersection)) THEN id
	ELSE -id
	END
FROM gtfs_2015.cube_route_nodes
ORDER BY route_id, direction_id, seq;

-- Aggregate the stops into strings
CREATE OR REPLACE VIEW gtfs_2015.cube_node_string AS
SELECT
	sorted_intersection.route_id,
	sorted_intersection.direction_id,
	string_agg(sorted_intersection.intersection_id, ',') AS nodes_agg
FROM
	(SELECT
		route_id,
		direction_id,
		seq,
		CASE WHEN (id IN (SELECT cube_node_id FROM gtfs_2015.stop_cube_node)) THEN id::text
		ELSE (-id)::text
		END AS intersection_id
	FROM gtfs_2015.cube_route_nodes
	ORDER BY route_id, direction_id, seq) AS sorted_intersection
GROUP BY sorted_intersection.route_id, sorted_intersection.direction_id



-- Matt's query
SELECT DISTINCT ON (route_id, direction_id) *
FROM (
	SELECT * FROM (
		SELECT t.route_id,
		t.shape_id,
		t.direction_id,
		count(t.shape_id) AS shape_count
		FROM gtfs_2015.trips t
			RIGHT OUTER JOIN gtfs_2015.common_routes_mat cr
				ON cr.route_id = t.route_id
		GROUP BY t.route_id, t.shape_id, t.direction_id
	) AS grouped
ORDER BY shape_count) AS ordered


-- FINAL TABLE
SELECT
	common_routes.route_id AS line_name,
	common_routes.route_short_name || '-' || node_string.direction_id AS long_name,
	1 AS mode,
	1 AS operator,
	1 AS vehicle_type,
	'T' AS one_way,
	'F' AS circular,
	EXTRACT (MINUTE FROM hw_peak.avg_head_time) AS headway_1,
	EXTRACT (MINUTE FROM hw_non_peak.avg_head_time) AS headway_2,
	round(xy_speed.xy_speed::numeric, 0) AS xy_speed,
	node_string.nodes_agg
FROM gtfs_2015.common_routes AS common_routes
JOIN gtfs_2015.headway_peak_avg AS hw_peak
	ON hw_peak.route_id = common_routes.route_id
JOIN gtfs_2015.headway_non_peak_avg AS hw_non_peak
	ON hw_non_peak.route_id = common_routes.route_id
JOIN gtfs_2015.xy_speed AS xy_speed
	ON xy_speed.route_id = common_routes.route_id
JOIN gtfs_2015.cube_node_string as node_string
	ON node_string.route_id = common_routes.route_id
