
$$
BEGIN
   SET resolve_fallback_snapshot_on_failure=true;
   SET @last_parent_snapshot = SELECT COALESCE(parent_id, 'HEAD') FROM (
      SELECT parent_id FROM ( SELECT history_meta('$Source_Profile_Attributes_Table_Name') )
        WHERE is_current=true);

   INSERT INTO
      $Database_Name.$Schema_Name.adwh_fact_profile_overlap_of_segments
      (date_key, merge_policy_id, segment1, segment2, count_of_overlap)
   SELECT
      to_date('$date_key') date_key,
      hash('$Merge_PolicyID') merge_policy_id,
      segments.segment1,
      segments.segment2,
      sum(number_of_profiles) count_of_overlap
   FROM
      (
         SELECT
            number_of_profiles,
            explode(
               transform(
                  flatten(
                     transform(
                        segments,
                        (x, i) -> IF(
                           (i < segments_size),
                           arrays_zip(
                              array_repeat(x, (segments_size - (i + 1))),
                              slice(
                                 segments,
                                 (i + 2),
                                 (segments_size - (i + 1))
                              )
                           ),
                           null
                        )
                     )
                  ),
                  x1 -> IF(
                     (x1['0'] < x1['1']),
                     named_struct('segment1', x1['0'], 'segment2', x1['1']),
                     named_struct('segment1', x1['1'], 'segment2', x1['0'])
                  )
               )
            ) segments
         FROM
            (
               SELECT
                 count(*) AS number_of_profiles,
                 first_value(segments) AS segments,
                 first_value(size(segments)) AS segments_size
               FROM
                  (
                     SELECT
                        array_sort(
                         flatten(
                           map_values(
                             transform_values(
                              segmentmembership,
                              (k, v) -> transform(map_keys(map_filter(v, (k1, v1) -> (v1.status <> 'exited'))), x -> hash(concat_ws('-', x, upper(k))))
                             )
                           )
                         )
                        ) AS segments
                     FROM
                        $Source_Profile_Attributes_Table_Name
                        $Source_Table_Snapshot_Clause
                  )
               WHERE
                  (size(segments) > 1)
               GROUP BY CAST(segments AS STRING)
            )
      )
   GROUP BY
      segments.segment1,
      segments.segment2;
END
$$;
