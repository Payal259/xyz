SELECT
  p._id,
  p.person.name.firstName,
  p.personalEmail.address,
  e.eventType,
  e.timestamp,
  e.web.webPageDetails.name
FROM
  "my_customer_dataset_mp_20260629_190845_480" p
JOIN
  "my_website_events_dataset" e
ON
  p.personalEmail.address = 
  e.identityMap['Email'][0].id