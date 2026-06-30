
$$
BEGIN
   SET resolve_fallback_snapshot_on_failure=true;
   SET @mp_hash = SELECT hash('$Merge_PolicyID') as mp_hash;
   SET @last_parent_snapshot = SELECT COALESCE(parent_id, 'HEAD') FROM (
      SELECT parent_id FROM ( SELECT history_meta('$Source_Profile_Attributes_Table_Name') )
        WHERE is_current=true);
   BEGIN TRANSACTION
      DELETE FROM $Database_Name.$Schema_Name.adwh_dim_overlap_namespaces
      WHERE merge_policy_id = CAST(@mp_hash AS INT);

      INSERT INTO
         $Database_Name.$Schema_Name.adwh_dim_overlap_namespaces
         (merge_policy_id, overlap_id, overlap_namespaces, overlap_description)
      SELECT
         a.merge_policy_id,
         a.overlap_id overlap_id,
         col as overlap_namespaces,
         concat_ws(',', a.overlap_description) overlap_description
      FROM
         (
            SELECT
               hash('$Merge_PolicyID') merge_policy_id,
               hash(overlap_id) overlap_id,
               overlap_id overlap_description,
               explode(overlap_id)
            FROM
               (
                  SELECT DISTINCT
                     array_sort(map_keys(identitymap)) overlap_id
                  FROM
                     $Source_Profile_Attributes_Table_Name
                  $Source_Table_Snapshot_Clause
               )
         )
         a;
   COMMIT;
END
$$;
