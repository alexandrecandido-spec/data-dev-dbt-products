WITH base AS (
  SELECT
    id AS user_pseudo_id,
    unique_session,
    ga_session_id,
    source,
    country AS mpv_country,
    device_category AS mpv_category,
    TO_DATE(event_date, 'yyyyMMdd') AS event_date_parsed,
    event_timestamp,
    event_params,
    element_at(filter(event_params, x -> x.key = 'env'), 1).value.string_value AS mpv_env,
    CAST(element_at(filter(event_params, x -> x.key = 'page_location'), 1).value.string_value AS STRING) AS mpv_page,
    CAST(date_format(TO_DATE(event_date, 'yyyyMMdd'), 'yyyyMM') AS INT) AS year_month_code,
    current_timestamp() AS sys_audit_updated_on
  FROM {{ ref('marketing__analytics_events') }}
  WHERE event_name = 'page_view'
),
win AS (
  SELECT
    unique_session,
    user_pseudo_id,
    source,
    mpv_country,
    mpv_category,
    event_date_parsed,
    event_timestamp AS mpv_event_timestamp,
    mpv_env,
    mpv_page,
    FIRST(mpv_page, TRUE) OVER (
      PARTITION BY unique_session
      ORDER BY event_timestamp
      ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS mpv_landing_page,
    LAST(element_at(filter(event_params, x -> x.key = 'source'),   1).value.string_value, TRUE) OVER (
      PARTITION BY unique_session
      ORDER BY event_timestamp
      ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS mpv_last_source,
    LAST(element_at(filter(event_params, x -> x.key = 'medium'),   1).value.string_value, TRUE) OVER (
      PARTITION BY unique_session
      ORDER BY event_timestamp
      ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS mpv_last_medium,
    LAST(element_at(filter(event_params, x -> x.key = 'campaign'), 1).value.string_value, TRUE) OVER (
      PARTITION BY unique_session
      ORDER BY event_timestamp
      ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS mpv_last_campaign,
    year_month_code
  FROM base
), 
dedup AS ( --deduplication applied due to possible duplicates in GA data -- deduplication needed to clean data sourced from GA4
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY user_pseudo_id, unique_session, mpv_event_timestamp
      ORDER BY CASE WHEN mpv_page IS NULL THEN 1 ELSE 0 END, mpv_event_timestamp ASC
    ) AS rn
  FROM win
)
SELECT
  user_pseudo_id,
  unique_session,
  source,
  mpv_country,
  mpv_category,
  event_date_parsed,
  mpv_event_timestamp,
  mpv_env,
  mpv_page,
  mpv_landing_page,
  mpv_last_source,
  mpv_last_medium,
  mpv_last_campaign,
  year_month_code
FROM dedup
WHERE rn = 1