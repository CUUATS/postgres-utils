
-- calculate average headway non-peak time
CREATE VIEW gtfs_2015.headway_non_peak_avg AS
SELECT 
	route_id, 
 	(max(arrival_time::interval) - min(arrival_time)::interval) / count(arrival_time) AS avg_head_time
FROM gtfs_2015.head_way_non_peak
GROUP BY route_id
ORDER BY route_id;


-- calculate average headway peak time
CREATE VIEW gtfs_2015.headway_peak_avg AS
SELECT 
	route_id, 
 	(max(arrival_time::interval) - min(arrival_time)::interval) / count(arrival_time) AS avg_head_time
FROM gtfs_2015.head_way_peak
GROUP BY route_id
ORDER BY route_id;