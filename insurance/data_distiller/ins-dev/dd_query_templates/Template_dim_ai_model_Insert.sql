
$$
BEGIN
  SET resolve_fallback_snapshot_on_failure=true;
  SET @last_parent_snapshot = SELECT COALESCE(parent_id, 'HEAD') FROM (
     SELECT parent_id FROM ( SELECT history_meta('$Source_Profile_Attributes_Table_Name') )
        WHERE is_current=true);

  INSERT INTO $Database_Name.$Schema_Name.adwh_dim_ai_models
   SELECT DISTINCT
     hash('$Merge_PolicyID') merge_policy_id,
     hash(concat_ws('-',col.name , get_json_object(col.values, '$.modelType')))model_id,
     col.name model_name,
     get_json_object(col.values, '$.modelType') modelType,
     current_timestamp created_date
    FROM (
		  SELECT explode(arr)
		   FROM (
				SELECT transform(json_object_keys(ai), x -> named_struct('name', x, 'values', get_json_object(ai, concat('$.', x)))) arr
				  FROM (
						SELECT to_json(struct($Source_Column_For_CAI_Models)) AS ai
						   FROM $Source_Profile_Attributes_Table_Name
                  $Source_Table_Snapshot_Clause
					)
			 )
		 ) a WHERE get_json_object(col.values, '$.modelType') IS NOT NULL
        AND NOT EXISTS (
         SELECT 1 FROM qsaccel.profile_agg.adwh_dim_ai_models
          WHERE merge_policy_id = hash('$Merge_PolicyID') AND
          hash(concat_ws('-',col.name , get_json_object(col.values, '$.modelType'))) = model_id
        );

END
$$;
