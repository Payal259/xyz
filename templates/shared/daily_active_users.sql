
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
