{{  
  config(
    materialized         = 'incremental',
    incremental_strategy = 'merge',
    partition_by         = ['year_month_day_code'],
    cluster_by           = ['year_month_day_code','session_status'],
    unique_key           = ['row_hash'],
    on_schema_change     = 'fail',
    tags                 = ['daily-6am']
  )  
}}

WITH existing_data AS (
  {{ get_existing_data(this, ['row_hash', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),

prepared AS (
    SELECT
        cls.*,
        CASE WHEN engage = 1 THEN 'Engaged' ELSE 'Bounced' END AS session_status
    FROM {{ ref('marketing_ga4_sessions_classified') }} cls
),

aggregated AS (
    SELECT
        date,
        year_month_day_code,
        source_ga4_classification,
        original_user_country,
        classified_country,
        env,
        landing_page,
        landing_page_domain,
        landing_page_path,
        last_source,
        last_medium,
        last_campaign,
        utm_ad_id,
        utm_content,
        utm_term,
        first_event_device,
        last_event_device,
        only_login_session,
        login_in_session,
        landing_page_type,
        user_type,
        session_status,

        COUNT(DISTINCT user_pseudo_id)                            AS distinct_user_count,
        COUNT(DISTINCT unique_session)                            AS distinct_session_count,
        SUM(trial)                                                AS total_trials,
        SUM(payment)                                              AS total_payments,
        SUM(CASE WHEN session_status = 'Engaged' THEN 1 END)      AS total_engagements,
        AVG(session_duration_minutes)                             AS avg_session_duration,
        APPROX_PERCENTILE(session_duration_minutes, 0.5)          AS median_session_duration,
        AVG(pageviews_per_session)                                AS avg_pageviews_per_session,
        APPROX_PERCENTILE(pageviews_per_session, 0.5)             AS median_pageviews_per_session
    FROM prepared
    GROUP BY
        date,
        year_month_day_code,
        source_ga4_classification,
        original_user_country,
        classified_country,
        env, 
        landing_page,
        landing_page_domain, 
        landing_page_path,
        last_source, 
        last_medium, 
        last_campaign,
        utm_ad_id, 
        utm_content, 
        utm_term,
        first_event_device, 
        last_event_device,
        only_login_session, 
        login_in_session,
        landing_page_type, 
        user_type, 
        session_status
),

final AS (
    SELECT *,
           MD5(CONCAT_WS('|',
                COALESCE(CAST(date                     AS STRING), 'NULL'),
                COALESCE(CAST(year_month_day_code      AS STRING), 'NULL'),
                COALESCE(source_ga4_classification, 'NULL'),
                COALESCE(original_user_country, 'NULL'),
                COALESCE(classified_country, 'NULL'),
                COALESCE(env, 'NULL'),
                COALESCE(landing_page, 'NULL'),
                COALESCE(landing_page_domain, 'NULL'),
                COALESCE(landing_page_path, 'NULL'),
                COALESCE(last_source, 'NULL'),
                COALESCE(last_medium, 'NULL'),
                COALESCE(last_campaign, 'NULL'),
                COALESCE(CAST(only_login_session       AS STRING), 'NULL'),
                COALESCE(CAST(login_in_session         AS STRING), 'NULL'),
                COALESCE(landing_page_type, 'NULL'),
                COALESCE(user_type, 'NULL'),
                COALESCE(session_status, 'NULL'),
                COALESCE(utm_ad_id, 'NULL'),
                COALESCE(utm_content, 'NULL'),
                COALESCE(utm_term, 'NULL'),
                COALESCE(first_event_device, 'NULL'),
                COALESCE(last_event_device, 'NULL')
           )) AS row_hash
    FROM aggregated
)

SELECT 
  f.*,
  COALESCE(e.sys_audit_created_on, current_timestamp)         AS sys_audit_created_on,
  COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products')   AS sys_audit_created_by,
  current_timestamp                                            AS sys_audit_updated_on,
  'data-dev-dbt-products'                                      AS sys_audit_updated_by
FROM final f
LEFT JOIN existing_data e
  ON f.row_hash = e.row_hash
{% if is_incremental() %}
WHERE f.year_month_day_code >= (
    SELECT COALESCE(MAX(year_month_day_code), 19000101) FROM {{ this }}
)
{% endif %}
