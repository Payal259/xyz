SELECT
  _id,
  timestamp,
  eventType,
  web.webPageDetails.name,
  web.webPageDetails.URL
FROM
  "my_website_events_dataset"
ORDER BY timestamp DESC
LIMIT 10