-- assumption: MTD has no sense of a static route
-- assumption: same shape id are considered same route

SELECT	DISTINCT ON (st.stop_id, arrival_time, shape_id)
		r.route_id,
		st.stop_id, 
		d.service_id,
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
WHERE (st.arrival_time LIKE '06%'
		OR st.arrival_time LIKE '07%'
	  	OR st.arrival_time LIKE '08%')
	AND stop_sequence = 1
	AND (route_long_name NOT LIKE '%Saturday' AND
	route_long_name NOT LIKE '%Sunday' AND
	route_long_name NOT LIKE '%Weekend' AND
	route_long_name NOT LIKE '%Evening' AND 
	route_long_name NOT LIKE '%Night' AND
	route_long_name NOT LIKE '%PM')
ORDER BY stop_id, arrival_time; 

-- Find how many service for that route
-- Create common routes that has greater than 50 services
CREATE MATERIALIZED VIEW gtfs_2015.common_routes AS 
SELECT r.route_id, r.route_short_name, count(t.service_id) AS service_count FROM gtfs_2015.routes r
	JOIN gtfs_2015.trips t
		ON t.route_id = r.route_id
GROUP BY r.route_id, r.route_short_name HAVING count(t.service_id) > 50;

