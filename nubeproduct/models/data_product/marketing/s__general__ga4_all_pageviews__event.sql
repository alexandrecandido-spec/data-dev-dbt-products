{{ config(
  materialized='incremental',
  incremental_strategy='merge',
  unique_key=['unique_session','event_timestamp'],
  on_schema_change='fail',
  tags=['daily-6am','marketing']
) }}

WITH filtered AS (
  SELECT
    CONCAT(CAST(source AS STRING), '-', CAST(user_pseudo_id AS STRING))                                 AS user_pseudo_id,
    source,
    FILTER(event_params, x -> x.key = 'source'           )[0].value.string_value                        AS event_source,
    FILTER(event_params, x -> x.key = 'medium'           )[0].value.string_value                        AS event_medium,
    FILTER(event_params, x -> x.key = 'campaign'         )[0].value.string_value                        AS event_campaign,
    FILTER(event_params, x -> x.key = 'content'          )[0].value.string_value                        AS event_content,
    FILTER(event_params, x -> x.key = 'term'             )[0].value.string_value                        AS event_term,
    FILTER(event_params, x -> x.key = 'percent_scrolled' )[0].value.string_value                        AS event_percent_scrolled,
    FILTER(event_params, x -> x.key = 'env'              )[0].value.string_value                        AS env,
    CAST(FILTER(event_params, x -> x.key = 'page_location')[0].value.string_value AS STRING)            AS page,
    country                                                                                         AS country,
    region                                                                                          AS region,
    device_category                                                                                     AS category,
    TO_DATE(event_date, 'yyyyMMdd')                                                                     AS event_date,
    event_timestamp,
    event_params
  FROM {{ref('marketing__analytics_events')}}
  WHERE event_name = 'page_view'
),
with_session AS (
  SELECT
    f.*,
    CONCAT(
      f.user_pseudo_id, '-',
      CAST(FILTER(f.event_params, x -> x.key = 'ga_session_id')[0].value.int_value AS STRING)
    ) AS unique_session
  FROM filtered f
),
final AS (
  SELECT DISTINCT
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
    FIRST_VALUE(page, TRUE) OVER (
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
    CAST(DATE_FORMAT(TO_DATE(FROM_UNIXTIME(event_timestamp / 1000000)), 'yyyyMM') AS INT) AS year_month_code,
    CURRENT_TIMESTAMP() AS sys_audit_updated_on
  FROM with_session
)
SELECT * FROM final
    {% if is_incremental() %}
        WHERE event_date >= (SELECT date_sub(MAX(sys_audit_updated_on), 5) FROM {{ this }})
    {% endif %}