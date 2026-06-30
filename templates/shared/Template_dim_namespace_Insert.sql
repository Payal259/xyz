
$$
BEGIN
   SET resolve_fallback_snapshot_on_failure=true;
   SET @mp_hash = SELECT hash('$Merge_PolicyID') as mp_hash;
   SET @last_parent_snapshot = SELECT COALESCE(parent_id, 'HEAD') FROM (
      SELECT parent_id FROM ( SELECT history_meta('$Source_Profile_Attributes_Table_Name') )
        WHERE is_current=true);
   BEGIN TRANSACTION
      DELETE FROM $Database_Name.$Schema_Name.adwh_dim_namespaces
      WHERE merge_policy_id = CAST(@mp_hash AS INT);

      INSERT INTO
         $Database_Name.$Schema_Name.adwh_dim_namespaces
         (merge_policy_id, namespace_id, namespace_description)
      SELECT DISTINCT
         a.merge_policy_id,
         hash(Key) namespace_id,
         key namespace_description
      FROM
         (
            SELECT
               hash('$Merge_PolicyID') merge_policy_id,
               explode(identitymap)
            FROM
               $Source_Profile_Attributes_Table_Name
            $Source_Table_Snapshot_Clause
         )
         a;
   COMMIT;
END
$$;
