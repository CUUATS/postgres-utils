-- create route with the series of intersection
REFRESH MATERIALIZED VIEW gtfs_2015.routes_nodes;
CREATE MATERIALIZED VIEW gtfs_2015.routes_nodes AS
SELECT cr.route_id, t.direction_id, i.int_id, COUNT(t.trip_id) FROM gtfs_2015.common_routes_mat cr
	JOIN gtfs_2015.trips t
		ON t.route_id = cr.route_id
	JOIN gtfs_2015.shape_int_comb i
		ON i.shape_id = t.shape_id
GROUP BY cr.route_id, i.int_id, t.direction_id
	HAVING COUNT(t.trip_id) > 5;

select * from gtfs_2015.common_routes_mat;
select * from gtfs_2015.routes;