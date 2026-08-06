
$$
BEGIN
   SET resolve_fallback_snapshot_on_failure=true;
   SET @last_parent_snapshot = SELECT COALESCE(parent_id, 'HEAD') FROM (
      SELECT parent_id FROM ( SELECT history_meta('$Source_Profile_Attributes_Table_Name') )
        WHERE is_current=true);
   SET @merge_policy_id_hash = SELECT hash('$Merge_PolicyID');

  INSERT INTO
     $Database_Name.$Schema_Name.adwh_fact_profile
     (date_key, merge_policy_id, count_of_identities, count_of_profiles, count_of_single_identity_profiles,count_of_orphan_profiles$Dest_Columns)
  SELECT
     a.date_key,
     a.merge_policy_id,
     count_of_identities,
     count_of_profiles,
     count_of_single_identity_profiles,
     count_of_orphan_profiles$Dest_Columns
  FROM
  (
      SELECT
         to_date('$date_key') date_key,
         hash('$Merge_PolicyID') merge_policy_id,
         sum(size(value)) count_of_identities,
         count(distinct Profile_ID) as count_of_profiles,
         sum(CASE WHEN identity_size=1 THEN 1 ELSE 0 END) count_of_single_identity_profiles,
         sum( CASE WHEN SegmentMembership is NULL THEN 1 ELSE 0 END) count_of_orphan_profiles$Dest_Columns
      FROM
         (
          SELECT
               explode(identitymap),
               identity_size ,
               SegmentMembership,
                Profile_ID$Dest_Columns
          FROM      (
                            SELECT
                               identitymap,
                               size(identitymap) identity_size ,
                                SegmentMembership,
                               UUID()  as Profile_ID$Source_Columns_With_Alias
                            FROM
                               $Source_Profile_Attributes_Table_Name
                            $Source_Table_Snapshot_Clause
                    )
         )
      GROUP BY
         date_key,
         merge_policy_id$Dest_Columns
   )
   a;
   /*
    * The stored procedure can perform 3 DML operations:
    *  1. DELETE data from the trendline table based on the bit flag parameter
    *  2. INSERT data into the trendline table from the source table based on the number of lookback days
    *  3. DELETE data from the fact profile tables based on the bit flag parameter
    *  With these parameters to the Stored procedure:
    *  CALL $Database_Name.$Schema_Name.sp_adwh_fact_profile_by_trendlines_v1('1',0,0)
    *  the DML operation achieved is only the Insert of 2 days of data into the adwh_fact_profile_by_trendlines table 
    *  and the delete data operations are not done.
   */
   CALL $Database_Name.$Schema_Name.sp_adwh_fact_profile_by_trendlines_v1('1',1,0,'@merge_policy_id_hash');

  -- Incremental SQL to populate hkg_adls_profile_count_history
  -- Only processes NEW records since last run using LEFT JOIN with IS NULL
  INSERT INTO hkg_adls_profile_count_history (date_key, merge_policy_id, total_profiles)
  WITH successful_process_dates AS (
    -- Get all dates where FACT_TABLES_PROCESSING was successful (last 365 days)
    SELECT DISTINCT
        CAST(process_date AS DATE) AS process_date
    FROM $Database_Name.$Schema_Name.adwh_lkup_process_delta_log
    WHERE process_name = 'FACT_TABLES_PROCESSING'
      AND process_status = 'SUCCESSFUL'
      AND process_date >= DATEADD(DAY, -365, CURRENT_DATE)
  ),

  current_profile_data AS (
    -- Get actual profile data from fact table
    SELECT
        CAST(f.date_key AS DATE) AS date_key,
        f.merge_policy_id,
        SUM(COALESCE(f.count_of_profiles, 0)) AS total_profiles
    FROM $Database_Name.$Schema_Name.adwh_fact_profile_by_trendlines f
    INNER JOIN successful_process_dates spd ON f.date_key = spd.process_date
    GROUP BY f.date_key, f.merge_policy_id
  ),

  zero_fill_data AS (
    -- Ensure zero entries for successful dates with no profile data
    SELECT
        spd.process_date AS date_key,
        mp.merge_policy_id,
        COALESCE(cpd.total_profiles, 0) AS total_profiles
    FROM successful_process_dates spd
    INNER JOIN $Database_Name.$Schema_Name.adwh_dim_merge_policies mp
        ON mp.merge_policy_id IS NOT NULL
    LEFT JOIN current_profile_data cpd
        ON spd.process_date = cpd.date_key
        AND mp.merge_policy_id = cpd.merge_policy_id
  ),

  incremental_data AS (
    -- Use LEFT JOIN with IS NULL to find only NEW records
    SELECT
        zf.date_key,
        zf.merge_policy_id,
        zf.total_profiles
    FROM zero_fill_data zf
    LEFT JOIN hkg_adls_profile_count_history ph
        ON zf.date_key = ph.date_key
        AND zf.merge_policy_id = ph.merge_policy_id
    WHERE ph.date_key IS NULL  -- This is the LEFT ANTI JOIN equivalent
      AND zf.date_key IS NOT NULL
      AND zf.merge_policy_id IS NOT NULL
  )

  -- Final: Only NEW records to be inserted
  SELECT
      date_key,
      cast(merge_policy_id as string) as merge_policy_id,
      total_profiles
  FROM incremental_data
  ORDER BY date_key, merge_policy_id;

END
$$;
