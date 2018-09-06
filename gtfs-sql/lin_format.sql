-- create the final table for lin
SELECT 
	cr.route_id,
	rn.direction_id,
	hwp.avg_head_time head_time_peak, 
	hwnp.avg_head_time head_time_non_peak,
	rts.max_time run_time,
	rts.speed_mi_per_hour xy_speed,
	rn.int_id n
FROM gtfs_2015.common_routes_mat cr
	JOIN gtfs_2015.headway_peak_avg hwp
		ON hwp.route_id = cr.route_id
	JOIN gtfs_2015.headway_non_peak_avg hwnp
		ON hwnp.route_id = cr.route_id
	JOIN gtfs_2015.runtime_speed rts
		ON rts.route_id = cr.route_id
	JOIN gtfs_2015.routes_nodes rn
		ON rn.route_id = cr.route_id
WHERE 
	cr.route_id NOT LIKE '%NIGHT' AND
	cr.route_id NOT LIKE '%WEEKEND' AND
	cr.route_id NOT LIKE '%EVENING' AND
	cr.route_id NOT LIKE '%SATURDAY'