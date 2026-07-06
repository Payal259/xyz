
INSERT OVERWRITE INTO
   $Database_Name.$Schema_Name.adwh_dim_br_namespace_destinations
   (destination_id, namespace_id, target_namespace, is_mapped, create_time, created_by)
SELECT DISTINCT
   hash(a.destinationID) destination_id,
   hash(a.sourceNamespace) namespace_id,
   a.targetNamespace target_namespace,
   a.isMapped is_mapped,
   date_format(a.createTime, 'yyyy-MM-dd HH:mm:sss') create_time,
   a.createdByID created_by
FROM
   $Source_Destination_Table_Name a;
