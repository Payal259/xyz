
-- =========================================================
-- SELECT
--  n.namespace_description,
--  f.count_of_profiles,
--  f.DATE_KEY
-- FROM qsaccel.profile_agg.adwh_fact_profile_by_namespace f
-- JOIN qsaccel.profile_agg.adwh_dim_namespaces n
--  ON f.namespace_id = n.namespace_id
-- where n.namespace_description='vynx_userid'
-- ORDER BY f.DATE_KEY

-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

SELECT 
 s._acp_system_metadata.ingestTime,
-- "{""acp_sourceBatchId"":""01KPXRBC3B8RCR2S744VV7MJX3"",""commitBatchId"":""01KPXRBC3B8RCR2S744VV7MJX3"",""trackingId"":""01KPXRBC3B8RCR2S744VV7MJX3"",""rowId"":""01KPXRBC3B8RCR2S744VV7MJX3-25769803776;"",""rowVersion"":1,""ingestTime"":1776968523715,""isDeleted"":false}",
 s.identityMap,
 s._repo.createDate,
 s.personalEmail,
 s.person
FROM profile_snapshot_export_5ef0ba95_0006_49bb_9d30_e3f8a17857ce s
WHERE s.identityMap['vynx_userid'] IS NOT NULL
ORDER BY s._repo.createDate DESC

----------------------------------------------------------------------------------------------------

-- select _cognizanttechnologys
-- FROM profile_snapshot_export_5ef0ba95_0006_49bb_9d30_e3f8a17857ce

set drop_system_columns=false

-- select to_json(_acp_system_metadata)
-- FROM profile_snapshot_export_5ef0ba95_0006_49bb_9d30_e3f8a17857ce


SELECT
D.OVERLAP_NAMESPACES,
D.OVERLAP_DESCRIPTION,
F.DATE_KEY,
F.COUNT_OF_IDENTITIES,
F.COUNT_OF_PROFILES,
F.COUNT_OF_SINGLE_IDENTITY_PROFILES

FROM qsaccel.profile_agg.adwh_dim_overlap_namespaces as D
Join
qsaccel.profile_agg.adwh_fact_profile_overlap_of_namespace as F

ON F.OVERLAP_ID= D.OVERLAP_ID

Limit 10

-- select * from qsaccel.profile_agg.adwh_fact_profile_by_namespace 