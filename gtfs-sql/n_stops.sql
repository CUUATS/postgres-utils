-- assumption: MTD has no sense of a static route
-- assumption: same shape id are considered same route

SELECT 	DISTINCT ON (st.stop_id, arrival_time, shape_id)
		r.route_id || ' ' || r.route_long_name || ' ' || r.route_short_name AS route_full_name,
		st.stop_id, 
		d.service_id,
		sh.shape_id,
		(SELECT i.id 
		   FROM street.intersection as i
		   ORDER BY sh.geom <#> i.shape LIMIT 1) AS int_id)
		to_timestamp(st.arrival_time, 'HH24 MI SS')::TIME AS arrival_time
FROM gtfs_2015.routes AS r
	JOIN gtfs_2015.trips AS t
		ON r.route_id = t.route_id
	JOIN gtfs_2015.stop_times as st
		ON t.trip_id = st.trip_id
	JOIN gtfs_2015.stops as s
		ON st.stop_id = s.stop_id
	JOIN gtfs_2015.int_stop as i
		ON i.stop_id = st.stop_id
	JOIN gtfs_2015.calendar_dates as d
		ON t.service_id = d.service_id
	JOIN gtfs_2015.shapes as sh
		ON sh.shape_id = t.shape_id
WHERE (st.arrival_time LIKE '09%'
	OR st.arrival_time LIKE '08%')
	AND (route_long_name NOT LIKE '%Saturday' AND
	route_long_name NOT LIKE '%Sunday' AND
	route_long_name NOT LIKE '%Weekend' AND
	route_long_name NOT LIKE '%Evening' AND 
	route_long_name NOT LIKE '%Night' AND
	route_long_name NOT LIKE '%PM')
ORDER BY stop_id, arrival_time, shape_id; 


-- Join 
-- I want to get stop sequence, int id
SELECT DISTINCT ON (st.trip_id, stop_id, st.stop_sequence)
	t.route_id,
	st.trip_id, 
	stop_id, 
	st.stop_sequence,
	s.int_id
FROM gtfs_2015.stop_times st
	JOIN gtfs_2015.trips t
		ON t.trip_id = st.trip_id
	JOIN gtfs_2015.shape_int_mat s
		ON t.shape_id = s.shape_id
WHERE t.route_id = 'GREEN' AND
	st.stop_sequence = 0
ORDER BY st.trip_id, st.stop_sequence;

-- ROUTE SEQUENCE
SELECT DISTINCT ON (r.route_id, s.int_id)
	r.route_id,
	s.int_id
FROM gtfs_2015.common_routes_mat r
	JOIN gtfs_2015.trips t
		ON r.route_id = t.route_id
	JOIN gtfs_2015.shape_int_mat s
		ON s.shape_id = t.shape_id
WHERE r.route_id = 'GREEN';

-- DROP MATERIALIZED VIEW gtfs_2015.shape_int_mat;
-- CREATE MATERIALIZED VIEW gtfs_2015.shape_int_mat AS
--  SELECT DISTINCT ON (s.shape_id, int_id)
--  	s.index,
--     s.shape_id,
--     ( SELECT i.id
--            FROM street.intersection i
--           ORDER BY (s.geom <#> i.shape)
--          LIMIT 1) AS int_id
--    FROM gtfs_2015.shapes s;

