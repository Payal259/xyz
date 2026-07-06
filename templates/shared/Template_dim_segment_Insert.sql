
$$
BEGIN
  SET resolve_fallback_snapshot_on_failure=true;
  SET @last_parent_snapshot = SELECT COALESCE(parent_id, 'HEAD') FROM (
     SELECT parent_id FROM ( SELECT history_meta('$Source_Segment_Definitions_Table_Name') )
        WHERE is_current=true);

  INSERT OVERWRITE INTO
     $Database_Name.$Schema_Name.adwh_dim_segments
     (segment_id, segment_and_namespace, segment_namespace, segment, segment_name, description, segment_status, create_date)
  SELECT DISTINCT
     hash(concat_ws('-', a.value[0].Id,
        CASE
           WHEN upper(a.key) = 'AEPSEGMENTS' THEN 'UPS'
           ELSE upper(a.key)
        END
     )) segment_id,
     concat_ws('-', a.value[0].Id,
        CASE
           WHEN upper(a.key) = 'AEPSEGMENTS' THEN 'UPS'
           ELSE upper(a.key)
        END
     ) segment_and_namespace,
     CASE
        WHEN upper(a.key) = 'AEPSEGMENTS' THEN 'UPS'
        ELSE upper(a.key)
     END AS segment_namespace,
     a.value[0].Id segment,
     a.segment_name segment_name,
     a.description description,
     a.segment_status segment_status,
     a.create_date create_date
  FROM
   (
      SELECT
         segmentName segment_name,
         description,
         segmentstatus segment_status,
         _repo.createdate create_date,
         explode(IdentityMap)
      FROM
         $Source_Segment_Definitions_Table_Name
      $Source_Table_Snapshot_Clause
   )
   a;
END
$$;
