
INSERT OVERWRITE INTO
   $Database_Name.$Schema_Name.adwh_dim_br_segment_destinations
   (destination_id, segment_id, create_time, update_time, start_date, end_date)
SELECT DISTINCT
   hash(a.destinationID) destination_id,
   hash(concat_ws('-', a.SegmentID,
      CASE
         WHEN upper(a.segmentNamespace) = 'AEPSEGMENTS' THEN 'UPS'
         ELSE upper(a.segmentNamespace)
      END
   )) segment_id,
   date_format(a.createTime, 'yyyy-MM-dd HH:mm:sss') create_time,
   date_format(a.updateTime, 'yyyy-MM-dd HH:mm:sss') update_time,
   date_format(a.startDate, 'yyyy-MM-dd') start_date,
   date_format(a.endDate, 'yyyy-MM-dd') end_date
FROM
   $Source_Destination_Table_Name a;
