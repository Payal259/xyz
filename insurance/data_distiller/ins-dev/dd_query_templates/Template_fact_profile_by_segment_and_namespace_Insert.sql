
$$
BEGIN
   SET resolve_fallback_snapshot_on_failure=true;
   SET @last_parent_snapshot = SELECT COALESCE(parent_id, 'HEAD') FROM (
      SELECT parent_id FROM ( SELECT history_meta('$Source_Profile_Attributes_Table_Name') )
        WHERE is_current=true);
   SET @merge_policy_id_hash = SELECT hash('$Merge_PolicyID');

    INSERT INTO
       $Database_Name.$Schema_Name.adwh_fact_profile_by_segment_and_namespace
       (date_key, merge_policy_id, namespace_id, segment_id, count_of_identities, count_of_profiles, count_of_single_identity_profiles$Dest_Columns)
    SELECT
       a.date_key,
       a.merge_policy_id,
       a.namespace_id,
       a.segment_id,
       count_of_identities,
       count_of_profiles,
       count_of_Single_Identity_profiles$Dest_Columns
    FROM
    (
       SELECT
          to_date('$date_key') date_key,
          hash('$Merge_PolicyID') merge_policy_id,
          namespace_id,
          hash(concat_ws('-', key, source_namespace)) segment_id,
          sum(identities) count_of_identities,
          count(distinct profile_ID) count_of_profiles,
          sum(Case when Identity_Size =1 then 1 else 0 end) count_of_Single_Identity_profiles$Dest_Columns

       FROM
          (
             SELECT
                namespace_id,
                Identity_Size,
                identities,
                upper(key) as source_namespace,
                explode(value),
                Profile_ID$Dest_Columns
             FROM
                (
                   SELECT
                      hash(Key) namespace_id,
                      Identity_Size,
                      size(value) identities,
                      explode(Segmentmembership),
                      Profile_ID$Dest_Columns
                   FROM
                      (
                         SELECT
                            Segmentmembership,
                            Identity_Size,
                            explode( identitymap),
                            Profile_ID$Dest_Columns
                         FROM
                         (
                              Select
                                  identitymap,
                                  transform_values(Segmentmembership, (k,v) ->  map_filter(v, (k1, v1) -> v1.status  <> 'exited')) Segmentmembership,
                                  Size( identitymap) Identity_Size ,
                                  UUID() as Profile_ID$Source_Columns_With_Alias
                               from
                                    $Source_Profile_Attributes_Table_Name
                                    $Source_Table_Snapshot_Clause
                            )
                      )
                )
          )
         GROUP BY
          namespace_id,
          segment_id$Dest_Columns
   )
   a;
   /*
    * The stored procedure can perform 3 DML operations:
    *  1. DELETE data from the trendline table based on the bit flag parameter
    *  2. INSERT data into the trendline table from the source table based on the number of lookback days
    *  3. DELETE data from the fact profile tables based on the bit flag parameter
    *  With these parameters to the Stored procedure:
    *  CALL $Database_Name.$Schema_Name.sp_adwh_fact_profile_by_segment_and_namespace_trendlines_v1('1',0,0)
    *  the DML operation achieved is only the Insert of 2 days of data into the adwh_fact_profile_by_segment_and_namespace_trendlines table
    *  and the delete data operations are not done.
   */
   CALL $Database_Name.$Schema_Name.sp_adwh_fact_profile_by_segment_and_namespace_trendlines_v1('1',1,0,'@merge_policy_id_hash');
END
$$;
