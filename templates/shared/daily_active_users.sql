-- ============================================================
-- updated via pull-edit-push test
-- name: Daily Active Users (DAU)
-- description: >
--   Counts unique ECIDs with at least one experience event
--   per day for the trailing 30-day window. Breaks down by
--   device type and channel for trend analysis.
-- category: analytics
-- aep_template_id:
-- owner: analytics-team
-- last_updated: 2024-06-01
-- tags: dau, engagement, daily, trend
-- ============================================================
-- final test
SELECT
    DATE(timestamp)                             AS event_date,
    device.type                                 AS device_type,
    channel.typeAtSource                        AS channel,
    COUNT(DISTINCT identityMap['ECID'][0].id)   AS unique_users,
    COUNT(1)                                    AS total_events
FROM
    experience_events
WHERE
    _acp_year >= YEAR(CURRENT_DATE - INTERVAL 30 DAY)
    AND timestamp >= CURRENT_TIMESTAMP - INTERVAL 30 DAY
    AND identityMap['ECID'][0].id IS NOT NULL
GROUP BY
    DATE(timestamp),
    device.type,
    channel.typeAtSource
ORDER BY
    event_date DESC,
    unique_users DESC;
