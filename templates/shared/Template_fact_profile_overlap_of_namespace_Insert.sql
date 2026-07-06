
$$
BEGIN
   SET resolve_fallback_snapshot_on_failure=true;
   SET @last_parent_snapshot = SELECT COALESCE(parent_id, 'HEAD') FROM (
      SELECT parent_id FROM ( SELECT history_meta('$Source_Profile_Attributes_Table_Name') )
        WHERE is_current=true);

   INSERT INTO
      $Database_Name.$Schema_Name.adwh_fact_profile_overlap_of_namespace
      (date_key, merge_policy_id, overlap_id, count_of_identities, count_of_profiles,count_of_Single_Identity_profiles$Dest_Columns)
   SELECT
     a.date_key,
     a.merge_policy_id,
     a.overlap_id,
     count_of_identities,
     count_of_profiles ,
     count_of_Single_Identity_profiles$Dest_Columns
  FROM
   (
      SELECT
         to_date('$date_key') date_key,
         hash('$Merge_PolicyID') merge_policy_id,
         overlap_id,
         sum(size(value)) count_of_identities,
         count(distinct profile_ID) count_of_profiles,
         sum(Case when Identity_Size =1 then 1 else 0 end) count_of_Single_Identity_profiles$Dest_Columns
      FROM
     (
      SELECT
         explode(identitymap),
         Identity_Size ,
         overlap_id,
          Profile_ID$Dest_Columns
      FROM
          (
             SELECT
                 identitymap,
                 Size( identitymap) Identity_Size ,
                 hash(array_sort(map_keys(identitymap))) overlap_id,
                 UUID() as Profile_ID$Source_Columns_With_Alias
              FROM
                   $Source_Profile_Attributes_Table_Name
                   $Source_Table_Snapshot_Clause
           )
      )

      GROUP BY
         overlap_id,
         merge_policy_id,
         date_key$Dest_Columns
   )
   a;
END
$$;
