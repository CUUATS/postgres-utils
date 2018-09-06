-- create a view for dist travel for each shape
CREATE VIEW gtfs_2015.dist_travel AS
SELECT shape_id, max(shape_dist_traveled) dist_travel FROM gtfs_2015.shapes
GROUP BY shape_id;

-- 
select * from gtfs_2015.dist_travel
order by dist_travel asc