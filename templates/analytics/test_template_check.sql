======= Test
SELECT
    timestamp,
    eventType,
    _id
FROM
    experience_events
WHERE
    _acp_year = YEAR(CURRENT_DATE)
LIMIT 10;
