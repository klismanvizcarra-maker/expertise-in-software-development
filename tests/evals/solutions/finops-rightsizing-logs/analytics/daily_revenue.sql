-- Ingresos de ayer
SELECT SUM(amount_cents) / 100 AS revenue
FROM analytics.events
WHERE event_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
  AND event_type = 'purchase';
