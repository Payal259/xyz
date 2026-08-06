-- ============================================================
-- name: Identity Resolution CTE
-- description: >
--   Reusable CTE that resolves ECID to CRM ID using the
--   identity graph. Import this as a CTE in other templates
--   by copying the WITH block. Handles multi-identity merging.
-- category: shared
-- aep_template_id:
-- owner: data-engineering
-- last_updated: 2024-06-01
-- tags: identity, ecid, crmid, cte, shared
-- ============================================================

WITH identity_map AS (
    SELECT DISTINCT
        identityMap['ECID'][0].id           AS ecid,
        identityMap['CRMID'][0].id          AS crmid,
        identityMap['Email'][0].id          AS email_hash,
        identityMap['ECID'][0].primary      AS is_primary_ecid
    FROM
        profile_snapshot_export
    WHERE
        identityMap['ECID'][0].id IS NOT NULL
        AND identityMap['CRMID'][0].id IS NOT NULL
)

SELECT
    im.crmid,
    im.ecid,
    im.email_hash,
    COUNT(ee.timestamp)     AS total_events
FROM
    identity_map im
JOIN
    experience_events ee
    ON ee.identityMap['ECID'][0].id = im.ecid
WHERE
    ee.timestamp >= CURRENT_TIMESTAMP - INTERVAL 7 DAY
GROUP BY
    im.crmid,
    im.ecid,
    im.email_hash
ORDER BY
    total_events DESC;
