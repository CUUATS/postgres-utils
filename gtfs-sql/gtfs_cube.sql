select r.route_short_name short_name, r.route_long_name long_name, 1 transit_mode, 'cumtd' op, 
from gtfs.routes r
left join gtfs.trips tq
	on r.route_id = t.route_id
join gtfs.stop_times st
	on t.trip_id = st.trip_id
join gtfs.stops s
	on st.stop_id = s.stop_id