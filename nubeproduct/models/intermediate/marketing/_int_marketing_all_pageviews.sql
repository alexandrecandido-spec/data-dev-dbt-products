WITH base AS (
  SELECT
    id AS user_pseudo_id,
    unique_session,
    source,
    country,
    region,
    device_category,
    TO_DATE(event_date, 'yyyyMMdd') AS event_date,
    event_timestamp,
    filter(event_params, x -> x.key = 'source')[0].value.string_value AS event_source,
    filter(event_params, x -> x.key = 'medium')[0].value.string_value AS event_medium,
    filter(event_params, x -> x.key = 'campaign')[0].value.string_value AS event_campaign,
    filter(event_params, x -> x.key = 'content')[0].value.string_value AS event_content,
    filter(event_params, x -> x.key = 'term')[0].value.string_value AS event_term,
    filter(event_params, x -> x.key = 'percent_scrolled')[0].value.string_value AS event_percent_scrolled,
    filter(event_params, x -> x.key = 'env')[0].value.string_value AS env,
    CAST(filter(event_params, x -> x.key = 'page_location')[0].value.string_value AS STRING) AS page
  FROM {{ ref('marketing__analytics_events') }}
  WHERE event_name = 'page_view'
),
win AS (
  SELECT
    user_pseudo_id,
    unique_session,
    source,
    country,
    region,
    device_category AS category,
    event_date,
    event_timestamp,
    env,
    page,
    FIRST(page, TRUE) OVER (
      PARTITION BY unique_session
      ORDER BY event_timestamp
      ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS landing_page,
    event_source,
    event_medium,
    event_campaign,
    event_content,
    event_term,
    event_percent_scrolled,
    CAST(date_format(TO_DATE(FROM_UNIXTIME(event_timestamp/1000000)), 'yyyyMM') AS INT) AS year_month_code
  FROM base
), 
dedup AS (
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY user_pseudo_id, unique_session, event_timestamp
      ORDER BY CASE WHEN page IS NULL THEN 1 ELSE 0 END, event_timestamp ASC
    ) AS rn
  FROM win
)

SELECT
  user_pseudo_id,
  unique_session,
  source,
  country,
  region,
  category,
  event_date,
  event_timestamp,
  env,
  page,
  landing_page,
  event_source,
  event_medium,
  event_campaign,
  event_content,
  event_term,
  event_percent_scrolled,
  year_month_code
FROM dedup
WHERE rn = 1