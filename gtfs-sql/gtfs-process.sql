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
SELECT dist_travel.route_id,
   calc_speed(dist_travel.dist_travel * .00018939, conv_inter_float(run_time.avg)) AS xy_speed
FROM gtfs_2015.dist_travel AS dist_travel
    JOIN gtfs_2015.run_time AS run_time
        ON dist_travel.route_id = run_time.route_id


-- Create the view for stop_id matching the intersection_id
CREATE OR REPLACE VIEW gtfs_2015.stop_intersection AS
SELECT s.stop_id,
  (SELECT i.id
   FROM street.intersection as i
   ORDER BY s.geom <#> i.shape LIMIT 1) AS int_id
FROM gtfs_2015.stops AS s;


-- Create the view for matching shape to closet intersection
WITH unique_int AS (
	SELECT DISTINCT ON (int_id)
		s.shape_id,
		(SELECT
		   i.id
		   FROM street.intersection as i
		   ORDER BY s.geom <#> i.shape LIMIT 1
	   )::text AS int_id,
	   s.shape_pt_sequence AS seq
	FROM gtfs_2015.shapes AS s
	WHERE s.shape_id = '100N')
SELECT string_agg(int_id, ', ')
FROM unique_int
ORDER BY seq;


-- Create a list of nodes that the bus route goes through
-- If it's a bus stop, node is positive, else negative
