
$$
BEGIN
   SET resolve_fallback_snapshot_on_failure=true;
   SET @last_parent_snapshot = SELECT COALESCE(parent_id, 'HEAD') FROM (
      SELECT parent_id FROM ( SELECT history_meta('$Source_Profile_Attributes_Table_Name') )
        WHERE is_current=true);
   SET @merge_policy_id_hash = SELECT hash('$Merge_PolicyID');

   INSERT INTO
      $Database_Name.$Schema_Name.adwh_fact_profile_by_segment
      (date_key, merge_policy_id, segment_id, count_of_identities, count_of_profiles, count_of_Single_Identity_profiles, count_of_calculated_realized_profiles, count_of_calculated_existing_profiles, count_of_calculated_exited_profiles$Dest_Columns)
    SELECT
              date_key,
              merge_policy_id,
              segment_id,
              count_of_identities,
              count_of_profiles,
              count_of_Single_Identity_profiles,
              count_of_calculated_realized_profiles,
              count_of_calculated_existing_profiles,
              count_of_calculated_exited_profiles$Dest_Columns
    FROM
           (
              SELECT
                 to_date('$date_key') date_key,
                 hash('$Merge_PolicyID') merge_policy_id,
                 hash(concat_ws('-', key, source_namespace)) segment_id,
                 sum(identities) FILTER (WHERE value.STATUS <> 'exited') count_of_identities,
                 count(distinct profile_ID) FILTER (WHERE value.STATUS <> 'exited') count_of_profiles,
                 sum(Case when Identity_Size =1 then 1 else 0 end) count_of_Single_Identity_profiles,
                 count(distinct profile_ID) FILTER (WHERE value.STATUS = 'realized' AND date(value.lastQualificationTime) = to_date('$date_key') - INTERVAL '1 DAY') count_of_calculated_realized_profiles,
                 count(distinct profile_ID) FILTER (WHERE value.STATUS = 'realized' AND date(value.lastQualificationTime) < to_date('$date_key') - INTERVAL '1 DAY') count_of_calculated_existing_profiles,
                 count(distinct profile_ID) FILTER (WHERE value.STATUS = 'exited' AND date(value.lastQualificationTime) = to_date('$date_key') - INTERVAL '1 DAY') count_of_calculated_exited_profiles$Dest_Columns
              FROM
                 (
                    SELECT
                       Identity_Size,
                       Profile_ID,
                       identities,
                       upper(key) as source_namespace,
                       explode(value)$Dest_Columns
                    FROM
                       (
                          SELECT
                             Identity_Size,
                             Profile_ID,
                             size(value) identities,
                             explode(Segmentmembership)$Dest_Columns
                          FROM
                             (
                                SELECT
                                   Segmentmembership,
                                   Identity_Size,
                                   Profile_ID,
                                   explode( identitymap)$Dest_Columns
                                FROM
                                (
                                     Select
                                         identitymap,
                                         transform_values(Segmentmembership, (k,v) -> map_filter(v, (k1, v1) -> v1.status IN ('realized', 'exited'))) Segmentmembership,
                                         Size(identitymap) Identity_Size ,
                                         UUID() as Profile_ID$Source_Columns_With_Alias
                                        from
                                        $Source_Profile_Attributes_Table_Name
                                        $Source_Table_Snapshot_Clause
                                   )
                             )
                       )
                 )
                GROUP BY
                 date_key, merge_policy_id, segment_id$Dest_Columns
           )
   a;
   /*
    * The stored procedure can perform 3 DML operations:
    *  1. DELETE data from the trendline table based on the bit flag parameter
    *  2. INSERT data into the trendline table from the source table based on the number of lookback days
    *  3. DELETE data from the fact profile tables based on the bit flag parameter
    *  With these parameters to the Stored procedure:
    *  CALL $Database_Name.$Schema_Name.sp_adwh_fact_profile_by_segment_trendlines_v1('1',0,0)
    *  the DML operation achieved is only the Insert of 2 days of data into the adwh_fact_profile_by_segment_trendlines table
    *  and the delete data operations are not done.
   */
   CALL $Database_Name.$Schema_Name.sp_adwh_fact_profile_by_segment_trendlines_v1('1',1,0,'@merge_policy_id_hash');

  -- Incremental SQL to populate hkg_adls_segment_profile_history
  -- Only processes NEW records since last run using LEFT JOIN with IS NULL
  INSERT INTO hkg_adls_segment_profile_history (dateKey, segmentId, totalProfiles)
  WITH process_dates AS (
    -- Get latest successful process dates per merge policy
    SELECT 
    a.merge_policy_id,
    MAX(a.process_date) AS last_process_date
    FROM $Database_Name.$Schema_Name.adwh_lkup_process_delta_log a
    JOIN $Database_Name.$Schema_Name.adwh_dim_merge_policies b
    ON a.merge_policy_id = b.merge_policy_id
    WHERE a.process_name = 'FACT_TABLES_PROCESSING'
    AND a.process_status = 'SUCCESSFUL'
    AND b.IS_DEFAULT_MERGE_POLICY = 't'
    AND b.merge_policy = '$Merge_PolicyID'
    GROUP BY a.merge_policy_id
  ),

  current_eqs_data AS (
    -- Get current EQS data (all available data)
    SELECT 
        CAST(f.date_key AS DATE) AS dateKey,
        s.segment AS segmentId,
        SUM(COALESCE(f.count_of_profiles, 0)) AS totalProfiles
    FROM $Database_Name.$Schema_Name.adwh_fact_profile_by_segment_trendlines f
    INNER JOIN process_dates pd ON f.merge_policy_id = pd.merge_policy_id
    FULL OUTER JOIN $Database_Name.$Schema_Name.adwh_dim_segments s ON f.segment_id = s.segment_id
    WHERE f.date_key >= DATEADD(DAY, -365, pd.last_process_date)
      AND s.segment IS NOT NULL
    GROUP BY f.date_key, s.segment
  ),

  incremental_data AS (
    -- Use LEFT JOIN with IS NULL to find only NEW records
    SELECT 
        ce.dateKey,
        ce.segmentId,
        ce.totalProfiles
    FROM current_eqs_data ce
    LEFT JOIN hkg_adls_segment_profile_history ed 
        ON ce.dateKey = ed.dateKey 
        AND ce.segmentId = ed.segmentId
    WHERE ed.dateKey IS NULL  -- This is the LEFT ANTI JOIN equivalent
      AND ce.dateKey IS NOT NULL 
      AND ce.segmentId IS NOT NULL
  )

  -- Final: Only NEW records to be inserted
  SELECT 
      dateKey,
      segmentId,
      totalProfiles
  FROM incremental_data
  ORDER BY dateKey, segmentId;

END
$$;
