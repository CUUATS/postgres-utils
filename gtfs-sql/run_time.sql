-- find the run-time of each trip
CREATE MATERIALIZED VIEW gtfs_2015.trip_run_times_peak AS 
SELECT 
	trip_id, 
	max(arrival_time::interval) - min(arrival_time::interval) AS run_time
FROM gtfs_2015.stop_times
WHERE
		arrival_time LIKE '06%'
		OR arrival_time LIKE '07%'
	  	OR arrival_time LIKE '08%'
GROUP BY trip_id
ORDER BY run_time DESC;

-- create run-time for common routes
CREATE MATERIALIZED VIEW gtfs_2015.max_run_time AS
SELECT 
		r.route_id, 
		max(rt.run_time)
FROM gtfs_2015.common_routes_mat r
	JOIN gtfs_2015.trips t
		ON t.route_id = r.route_id
	JOIN 
		(
		SELECT 
			trip_id, 
			max(arrival_time::interval) - min(arrival_time::interval) AS run_time
		FROM gtfs_2015.stop_times
		WHERE
				arrival_time LIKE '06%'
				OR arrival_time LIKE '07%'
				OR arrival_time LIKE '08%'
		GROUP BY trip_id
		ORDER BY run_time DESC
		) AS rt
		ON t.trip_id = rt.trip_id
GROUP BY r.route_id;


-- create run-time and speed for common routes
CREATE MATERIALIZED VIEW gtfs_2015.runtime_speed AS
SELECT 
 		r.route_id,
		MAX(rt.run_time) AS max_time,
 		AVG(calc_speed(dt.dist_travel * .00018939 , conv_inter_float(rt.run_time))) AS speed_mi_per_hour
FROM gtfs_2015.common_routes_mat r
	JOIN gtfs_2015.trips t
		ON t.route_id = r.route_id
	JOIN 
		(
		SELECT 
			trip_id, 
			max(arrival_time::interval) - min(arrival_time::interval) AS run_time
		FROM gtfs_2015.stop_times
		WHERE
				arrival_time LIKE '06%'
				OR arrival_time LIKE '07%'
				OR arrival_time LIKE '08%'
		GROUP BY trip_id
		ORDER BY run_time DESC
		) AS rt
		ON t.trip_id = rt.trip_id
	JOIN gtfs_2015.dist_travel dt
		ON dt.shape_id = t.shape_id
WHERE 
	rt.run_time::text <> '00:00:00' AND 
	rt.run_time > interval '00:05:00'
GROUP BY r.route_id;

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


