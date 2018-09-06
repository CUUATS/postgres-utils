
-- Create a table view for stop_id and intersection_id
CREATE OR REPLACE VIEW gtfs_2015.int_stop AS
SELECT s.stop_id,
  (SELECT i.id 
   FROM street.intersection as i
   ORDER BY s.geom <#> i.shape LIMIT 1) AS int_id
FROM gtfs_2015.stops AS s;

-- Create a table for shape_id and the closet intersection_id
CREATE MATERIALIZED VIEW gtfs_2015.shape_int_comb AS 
SELECT
	s.shape_id,
	array_agg((SELECT
				   i.id 
				   FROM street.intersection as i
				   ORDER BY s.geom <#> i.shape LIMIT 1 
			  		)::text
			   			ORDER BY s.shape_pt_sequence, ', ') AS int_id
FROM gtfs_2015.shapes AS s
WHERE s.shape_id = '100N'
GROUP BY s.shape_id;

Select * from gtfs_2015.shape_int_comb;


-- CREATE MATERIALIZED VIEW gtfs_2015.stop_int_mat AS 
-- SELECT s.stop_id,
-- 	s.shape_pt_sequence,
--   (SELECT i.id 
--    FROM street.intersection as i
--    ORDER BY s.geom <#> i.shape LIMIT 1) AS int_id
-- FROM gtfs_2015.stops AS s;

-- select * from gtfs_2015.shape_int_mat;
