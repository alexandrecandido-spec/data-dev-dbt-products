WITH base AS (
    SELECT
    id AS user_pseudo_id,
    unique_session,
    source,
    event_name,
    event_timestamp,
    device_category AS event_device,
    event_params
  FROM {{ ref('marketing__analytics_events') }}
  WHERE event_name LIKE '%clicked%' OR event_name = 'scroll'
),
enriched AS (
  SELECT
    user_pseudo_id,
    unique_session,
    source,
    event_timestamp,
    TO_DATE(FROM_UNIXTIME(event_timestamp / 1000000)) AS event_date,
    event_name,
    CAST(element_at(filter(event_params, x -> x.key = 'page_location'), 1).value.string_value AS STRING) AS event_page,
    element_at(filter(event_params, x -> x.key = 'eventAction'), 1).value.string_value AS event_action,
    event_device,
    CAST(date_format(TO_DATE(FROM_UNIXTIME(event_timestamp / 1000000)), 'yyyyMM') AS INT) AS year_month_code
  FROM base
),
dedup AS (
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY user_pseudo_id, unique_session, event_timestamp, event_name
      ORDER BY event_timestamp DESC
    ) AS rn
  FROM enriched
)

SELECT
  user_pseudo_id,
  unique_session,
  source,
  event_timestamp,
  event_date,
  event_name,
  event_page,
  event_action,
  event_device,
  year_month_code
FROM dedup
WHERE rn = 1