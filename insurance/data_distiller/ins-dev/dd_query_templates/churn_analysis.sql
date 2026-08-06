
-- ============================================================
-- name: Churn Analysis - 60 Day Window
-- description: >
--   Identifies users who have not had any experience events
--   in the last 60 days, segmented by their last known channel.
--   Use for churn prediction model input datasets.
-- category: retention
-- aep_template_id:
-- owner: analytics-team
-- last_updated: 2024-06-01
-- tags: churn, retention, 60d, segmentation
-- ============================================================

WITH last_activity AS (
    SELECT
        identityMap['ECID'][0].id                  AS ecid,
        MAX(timestamp)                              AS last_event_ts,
        LAST(web.webPageDetails.name, true)         AS last_page,
        LAST(channel.typeAtSource, true)            AS last_channel
    FROM
        experience_events
    WHERE
        _acp_year >= YEAR(CURRENT_DATE - INTERVAL 90 DAY)
        AND timestamp >= CURRENT_TIMESTAMP - INTERVAL 90 DAY
        AND identityMap['ECID'][0].id IS NOT NULL
    GROUP BY
        identityMap['ECID'][0].id
),

churned_users AS (
    SELECT
        ecid,
        last_event_ts,
        last_page,
        last_channel,
        DATEDIFF(CURRENT_DATE, DATE(last_event_ts)) AS days_inactive
    FROM
        last_activity
    WHERE
        last_event_ts < CURRENT_TIMESTAMP - INTERVAL 60 DAY
)

SELECT
    ecid,
    last_event_ts,
    last_page,
    COALESCE(last_channel, 'unknown')   AS last_channel,
    days_inactive,
    CASE
        WHEN days_inactive BETWEEN 60 AND 90  THEN 'at_risk'
        WHEN days_inactive BETWEEN 91 AND 180 THEN 'churned'
        ELSE 'deeply_churned'
    END                                 AS churn_segment
FROM
    churned_users
ORDER BY
    days_inactive DESC;
