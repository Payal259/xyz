
$$
BEGIN
 SET resolve_fallback_snapshot_on_failure=true;
 SET @last_parent_snapshot = SELECT COALESCE(parent_id, 'HEAD') FROM (
 SELECT parent_id FROM (SELECT history_meta('$Source_Profile_Attributes_Table_Name') )
        WHERE is_current=true);

 INSERT INTO $Database_Name.$Schema_Name.adwh_fact_profile_by_segment_ai_models
 SELECT DISTINCT
  current_date date_key,
  hash('$Merge_PolicyID') merge_policy_id,
  model_id,
  hash(concat_ws('-', key, source_namespace)) segment_id,
  to_date(scoreDate) score_date,
  int(score) score,
  count(score) count_of_profiles,
  current_timestamp  created_date
 FROM (
  SELECT
   hash(concat_ws('-',model_name , modelType))model_id,
   scoreDate,
   score,
   Upper(key) as source_namespace,
   explode(value)
  FROM (
    SELECT
     explode(segment),
     col.name model_name,
     get_json_object(col.values, '$.score') score,
     get_json_object(col.values, '$.modelType') modelType,
     get_json_object(col.values, '$.scoreDate') scoreDate
    FROM (
		  SELECT segment, explode(arr)
		   FROM (
				SELECT segment, transform(json_object_keys(ai), x -> named_struct('name', x, 'values', get_json_object(ai, concat('$.', x)))) arr
				 FROM (
				  SELECT
					 Segmentmembership segment,
					 to_json(struct($Source_Column_For_CAI_Models)) as ai
           FROM $Source_Profile_Attributes_Table_Name $Source_Table_Snapshot_Clause
				 )
			 )
		) WHERE segment IS NOT NULL
	) WHERE modelType IS NOT NULL
 ) a WHERE value.status !='exited' AND
      NOT EXISTS (
       SELECT 1 FROM $Database_Name.$Schema_Name.adwh_fact_profile_by_segment_ai_models b
        WHERE b.merge_policy_id = hash('$Merge_PolicyID') AND b.segment_id = hash(concat_ws('-', key, source_namespace))
        AND b.model_id = a.model_id AND b.score_date = to_date(a.scoreDate))
  GROUP BY
  merge_policy_id,
  model_id,
  hash(concat_ws('-', key, source_namespace)),
  to_date(scoreDate),
  score;
END
$$;
