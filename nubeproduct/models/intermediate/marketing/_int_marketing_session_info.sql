WITH extracted AS (
  SELECT
    unique_session,
    source,
    COALESCE(
      CAST(element_at(filter(d.event_params, x -> x.key = 'session_engaged'), 1).value.int_value   AS BIGINT),
      CAST(element_at(filter(d.event_params, x -> x.key = 'session_engaged'), 1).value.string_value AS BIGINT)
    ) AS session_engaged,
    event_timestamp
  FROM {{ ref('marketing__analytics_events') }} d
  WHERE user_pseudo_id IS NOT NULL
    AND element_at(filter(event_params, x -> x.key = 'ga_session_id'), 1).value.int_value IS NOT NULL
),
win AS (
  SELECT
    unique_session,
    source,
    MAX(session_engaged) OVER (
      PARTITION BY unique_session
      ORDER BY event_timestamp
      ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS engage,
    MIN(event_timestamp) OVER (
      PARTITION BY unique_session
      ORDER BY event_timestamp
      ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS start_session_time,
    MAX(event_timestamp) OVER (
      PARTITION BY unique_session
      ORDER BY event_timestamp
      ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS end_session_time,
    FIRST_VALUE(source) OVER (
      PARTITION BY unique_session
      ORDER BY event_timestamp
      ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS session_source
  FROM extracted
)
SELECT DISTINCT
  unique_session,
  session_source as source,
  engage,
  start_session_time,
  end_session_time,
  TO_DATE(FROM_UNIXTIME(start_session_time / 1000000)) AS start_session_date,
  TO_DATE(FROM_UNIXTIME(end_session_time   / 1000000)) AS end_session_date,
  CAST(
    (YEAR(FROM_UNIXTIME(start_session_time / 1000000)) * 100 +
     MONTH(FROM_UNIXTIME(start_session_time / 1000000))) AS INT
  ) AS year_month_code
FROM win