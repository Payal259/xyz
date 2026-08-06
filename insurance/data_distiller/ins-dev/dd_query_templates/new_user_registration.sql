-- ============================================================
-- name: New User Registration Events
-- description: >
--   Captures all new user registration experience events
--   within a rolling 7-day window. Includes UTM parameters
--   for attribution and acquisition channel analysis.
-- category: acquisition
-- aep_template_id:
-- owner: analytics-team
-- last_updated: 2024-06-01
-- tags: acquisition, registration, new-user, utm, attribution
-- ============================================================

SELECT
    identityMap['ECID'][0].id                                       AS ecid,
    timestamp                                                        AS registration_ts,
    DATE(timestamp)                                                  AS registration_date,
    web.webReferrer.URL                                              AS referrer_url,
    placeContext.geo.countryCode                                     AS country_code,
    device.type                                                      AS device_type,
    environment.browserDetails.userAgent                             AS user_agent,
    _myorg.marketing.utmSource                                       AS utm_source,
    _myorg.marketing.utmMedium                                       AS utm_medium,
    _myorg.marketing.utmCampaign                                     AS utm_campaign,
    _myorg.marketing.utmContent                                      AS utm_content,
    CASE
        WHEN _myorg.marketing.utmMedium = 'cpc'     THEN 'Paid Search'
        WHEN _myorg.marketing.utmMedium = 'email'   THEN 'Email'
        WHEN _myorg.marketing.utmMedium = 'social'  THEN 'Paid Social'
        WHEN web.webReferrer.URL LIKE '%google%'    THEN 'Organic Search'
        WHEN web.webReferrer.URL IS NULL            THEN 'Direct'
        ELSE 'Other'
    END                                                              AS acquisition_channel
FROM
    experience_events
WHERE
    _acp_year = YEAR(CURRENT_DATE)
    AND timestamp >= CURRENT_TIMESTAMP - INTERVAL 7 DAY
    AND eventType = 'web.formFilledOut'
    AND _myorg.eventName = 'user_registration'
    AND identityMap['ECID'][0].id IS NOT NULL
ORDER BY
    registration_ts DESC;
