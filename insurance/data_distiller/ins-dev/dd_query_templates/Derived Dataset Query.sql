CREATE TABLE derived_campaign_deliverability_w_profiles AS
SELECT
  _experience.customerJourneyManagement.messageExecution.campaignID AS campaign_id,
  DATE(timestamp)                                                   AS event_date,

  COUNT(1) AS total_events,

  SUM(CASE WHEN _experience.customerJourneyManagement.messageDeliveryfeedback.feedbackStatus = 'sent'      THEN 1 END) AS sent_count,
  SUM(CASE WHEN _experience.customerJourneyManagement.messageDeliveryfeedback.feedbackStatus = 'delivered' THEN 1 END) AS delivered_count,
  SUM(CASE WHEN _experience.customerJourneyManagement.messageDeliveryfeedback.feedbackStatus = 'error'     THEN 1 END) AS error_count,
  SUM(CASE WHEN _experience.customerJourneyManagement.messageDeliveryfeedback.feedbackStatus = 'bounce'    THEN 1 END) AS bounce_count,

  COUNT(DISTINCT _experience.customerJourneyManagement.messageProfile.messageProfileID) AS unique_message_profiles,

  ROUND(
    (SUM(CASE WHEN _experience.customerJourneyManagement.messageDeliveryfeedback.feedbackStatus = 'delivered' THEN 1 END) / COUNT(1)) * 100
  , 2) AS delivery_rate_percent,

  ROUND(
    (SUM(CASE WHEN _experience.customerJourneyManagement.messageDeliveryfeedback.feedbackStatus = 'bounce'    THEN 1 END) / COUNT(1)) * 100
  , 2) AS bounce_rate_percent

FROM ajo_message_feedback_event_dataset
GROUP BY campaign_id, event_date
ORDER BY event_date DESC;