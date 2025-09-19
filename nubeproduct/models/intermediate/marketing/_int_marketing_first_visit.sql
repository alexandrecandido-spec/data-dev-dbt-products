WITH base AS (
  SELECT
    id AS user_pseudo_id,
    source,
    event_timestamp,
    TO_DATE(FROM_UNIXTIME(event_timestamp / 1000000)) AS first_visit_date,
    CAST(date_format(TO_DATE(FROM_UNIXTIME(event_timestamp / 1000000)), 'yyyyMM') AS INT) AS year_month_code
  FROM {{ ref('marketing__analytics_events') }}
  WHERE event_name = 'first_visit' and user_pseudo_id IS NOT NULL
),
ranked AS (
  SELECT
    b.*,
    ROW_NUMBER() OVER (
      PARTITION BY user_pseudo_id
      ORDER BY event_timestamp
    ) AS row_num
  FROM base b
)
SELECT
  user_pseudo_id,
  source,
  event_timestamp,
  first_visit_date,
  year_month_code
FROM ranked
WHERE row_num = 1