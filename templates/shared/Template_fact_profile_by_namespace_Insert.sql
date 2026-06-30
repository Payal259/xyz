
$$
BEGIN
   SET resolve_fallback_snapshot_on_failure=true;
   SET @last_parent_snapshot = SELECT COALESCE(parent_id, 'HEAD') FROM (
      SELECT parent_id FROM ( SELECT history_meta('$Source_Profile_Attributes_Table_Name') )
        WHERE is_current=true);
   SET @merge_policy_id_hash = SELECT hash('$Merge_PolicyID');

   INSERT INTO
      $Database_Name.$Schema_Name.adwh_fact_profile_by_namespace
      (date_key, merge_policy_id, namespace_id, count_of_identities, count_of_profiles, count_of_single_identity_profiles$Dest_Columns)
   SELECT
      a.date_key,
      a.merge_policy_id,
      a.namespace_id,
      count_of_identities,
      count_of_profiles,
      count_of_single_identity_profiles$Dest_Columns
   FROM
   (
      SELECT
         to_date('$date_key') date_key,
         hash('$Merge_PolicyID') merge_policy_id,
         hash(Key) namespace_id,
         sum(size(value)) count_of_identities,
         count(distinct Profile_ID) as count_of_profiles,
         sum(CASE WHEN identity_size=1 THEN 1 ELSE 0 END) count_of_single_identity_profiles$Dest_Columns
      FROM
         (
          SELECT
               explode(identitymap),
               identity_size ,
                Profile_ID$Dest_Columns
          FROM      (
                            SELECT
                               identitymap,
                               size(identitymap) identity_size ,
                               UUID()  as Profile_ID$Source_Columns_With_Alias
                            FROM
                               $Source_Profile_Attributes_Table_Name
                            $Source_Table_Snapshot_Clause
                    )
         )
      GROUP BY
         namespace_id$Dest_Columns
   )
   a;
   /*
    * The stored procedure can perform 3 DML operations:
    *  1. DELETE data from the trendline table based on the bit flag parameter
    *  2. INSERT data into the trendline table from the source table based on the number of lookback days
    *  3. DELETE data from the fact profile tables based on the bit flag parameter
    *  With these parameters to the Stored procedure:
    *  CALL $Database_Name.$Schema_Name.sp_adwh_fact_profile_by_namespace_trendlines_v1('1',0,0)
    *  the DML operation achieved is only the Insert of 2 days of data into the adwh_fact_profile_by_namespace_trendlines table
    *  and the delete data operations are not done.
   */
   CALL $Database_Name.$Schema_Name.sp_adwh_fact_profile_by_namespace_trendlines_v1('1',1,0,'@merge_policy_id_hash');
END
$$;
