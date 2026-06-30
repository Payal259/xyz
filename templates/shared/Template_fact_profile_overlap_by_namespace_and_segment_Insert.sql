
$$
BEGIN
   SET resolve_fallback_snapshot_on_failure=true;
   SET @last_parent_snapshot = SELECT COALESCE(parent_id, 'HEAD') FROM (
      SELECT parent_id FROM ( SELECT history_meta('$Source_Profile_Attributes_Table_Name') )
        WHERE is_current=true);

   INSERT INTO
      $Database_Name.$Schema_Name.adwh_fact_profile_overlap_by_namespace_and_segment
      (date_key, merge_policy_id, namespace_id, overlap_id, segment_id, count_of_identities, count_of_profiles, count_of_Single_Identity_profiles$Dest_Columns)
   SELECT
      a.date_key,
      a.merge_policy_id,
      a.namespace_id,
      a.overlap_id,
      a.segment_id,
      count_of_identities,
      count_of_profiles,
      count_of_Single_Identity_profiles$Dest_Columns
   FROM
   (
      SELECT
         to_date('$date_key') date_key,
         hash('$Merge_PolicyID') merge_policy_id,
         overlap_id,
         segment_id,
         hash(key) as  namespace_id,
         sum(size(value))  count_of_identities,
         count(distinct Profile_ID) count_of_profiles,
         sum(Case when Identity_Size =1 then 1 else 0 end) count_of_Single_Identity_profiles$Dest_Columns
      FROM
       (
       SELECT
          overlap_id,
          hash(concat_ws('-', key, source_namespace)) segment_id,
          Identity_Size ,
          Profile_ID  ,
          source_namespace,
          explode(identitymap)$Dest_Columns
          FROM
         (
            SELECT
               overlap_id,
               Identity_Size ,
               Profile_ID  ,
               identitymap,
               upper(key) as source_namespace,
               explode(value)$Dest_Columns
            FROM
               (
               SELECT
                  explode(Segmentmembership)  ,
                  overlap_id,
                  Identity_Size ,
                  identitymap,
                  Profile_ID$Dest_Columns
               FROM
                 (
                    SELECT
                          transform_values(Segmentmembership, (k,v) ->  map_filter(v, (k1, v1) -> v1.status  <> 'exited')) Segmentmembership ,
                          hash(array_sort(map_keys(identitymap))) overlap_id,
                           Size( identitymap) Identity_Size ,
                           identitymap,
                          UUID()  as Profile_ID$Source_Columns_With_Alias
                        FROM
                        $Source_Profile_Attributes_Table_Name
                        $Source_Table_Snapshot_Clause
                  WHERE segmentmembership is not null
                )
            )
          )
         )
       GROUP BY
         overlap_id,
         segment_id,
         key$Dest_Columns
   )
   a;
END
$$;
