{{ config(
    materialized         = 'incremental',
    incremental_strategy = 'merge',
    partition_by         = ['year_month_day_code'],
    cluster_by           = ['year_month_day_code','session_status'],
    unique_key           = ['row_hash'],
    on_schema_change     = 'fail',
    tags                 = ['daily-6am']
) }}

WITH existing_data AS (
  {{ get_existing_data(this, ['row_hash', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),

attribution_int AS (
  SELECT *
  FROM {{ ref('_int_marketing__ga4_sessions_attribution') }}
  {% if is_incremental() %}
    WHERE year_month_day_code >= (
            SELECT COALESCE(MAX(year_month_day_code), 19000101)
            FROM existing_data
          )
      AND sys_audit_updated_on >= (
            SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01')
            FROM existing_data
          )
  {% else %}
    WHERE date >= DATE '2024-01-01'
  {% endif %}
)

SELECT
  sd.year_month_day_code,
  sd.date,
  sd.source_ga4_classification,
  sd.original_user_country,
  sd.classified_country,
  sd.env,
  sd.landing_page,
  sd.landing_page_domain,
  sd.landing_page_path,
  sd.last_source,
  sd.last_medium,
  sd.last_campaign,
  sd.first_event_device,
  sd.last_event_device,
  sd.only_login_session,
  sd.login_in_session,
  sd.landing_page_type,
  sd.user_type,
  sd.session_status,
  sd.utm_ad_id,
  sd.utm_content,
  sd.utm_term,
  sd.mkt_source,
  sd.mkt_subteam,
  sd.url_owner,
  sd.url_content_type,
  sd.distinct_user_count,
  sd.distinct_session_count,
  sd.total_trials,
  sd.total_payments,
  sd.total_engagements,
  sd.avg_session_duration,
  sd.median_session_duration,
  sd.avg_pageviews_per_session,
  sd.median_pageviews_per_session,
  sd.row_hash,
  COALESCE(e.sys_audit_created_on, current_timestamp)       AS sys_audit_created_on,
  COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
  current_timestamp                                          AS sys_audit_updated_on,
  'data-dev-dbt-products'                                    AS sys_audit_updated_by

FROM attribution_int sd
LEFT JOIN existing_data e
  ON sd.row_hash = e.row_hash
