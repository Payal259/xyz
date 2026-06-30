
$$
BEGIN
 INSERT OVERWRITE INTO
   $Database_Name.$Schema_Name.adwh_dim_destination
   (destination_id, destination, destination_name, destination_platform, destination_platform_id, create_time, created_by_id, destination_description, destination_status, version_number)
 SELECT DISTINCT
   hash(a.destinationID) destination_id,
   a.destinationID destination,
   a.destinationName destination_name,
   a.destinationPlatform destination_platform,
   hash(a.connectionSpecID) destination_platform_id,
   date_format(a.createTime, 'yyyy-MM-dd HH:mm:sss') create_time,
   a.createdByID created_by_id,
   a.destinationDescription destination_description,
   a.destinationStatus destination_status,
   a.version version_number
 FROM
   $Source_Destination_Table_Name a;

 INSERT OVERWRITE INTO
   $Database_Name.$Schema_Name.adwh_dim_destination_platform
   (destination_platform_id, destination_platform, destination_platform_name, destination_category, destination_frequency)
 SELECT DISTINCT
   hash(a.connectionSpecID) destination_platform_id,
   a.connectionSpecID destination_platform,
   a.destinationPlatform destination_platform_name,
   a.destinationCategory destination_category,
   a.destinationFrequency destination_frequency
 FROM
   $Source_Destination_Table_Name a;
END
$$;
