-- depends_on: {{ ref('marketing_ga4_sessions_classified') }}

{{ 
  config(
    materialized         = 'incremental',
    incremental_strategy = 'merge',
    partition_by         = ['year_month_day_code'],
    cluster_by           = ['year_month_day_code','session_status'],
    unique_key           = ['row_hash'],
    on_schema_change     = 'fail',
    tags                 = ['daily-6am'],
    pre_hook = [
      "
      {% if is_incremental() %}
        -- Borrar particiones desde (MAX updated_on - 5 días) hasta hoy -> 6 días en total (incluye extremos)
        WITH b AS (
          SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01') AS last_upd
          FROM {{ this }}
        ),
        dd AS (
          SELECT EXPLODE(SEQUENCE(DATE_SUB(DATE(b.last_upd), 5), CURRENT_DATE)) AS d
          FROM b
        )
        DELETE FROM {{ this }}
        WHERE year_month_day_code IN (
          SELECT CAST(date_format(d,'yyyyMMdd') AS INT) FROM dd
        );
      {% endif %}
      "
    ]
  ) 
}}

WITH baseline AS (
  {% if is_incremental() %}
  SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01') AS last_upd
  FROM {{ this }}
  {% else %}
  SELECT TIMESTAMP '1900-01-01' AS last_upd
  {% endif %}
),

prepared AS (
  SELECT
      cls.*,
      CASE WHEN engage = 1 THEN 'Engaged' ELSE 'Bounced' END AS session_status
  FROM {{ ref('marketing_ga4_sessions_classified') }} cls
  CROSS JOIN baseline b
  {% if is_incremental() %}
  -- hoy + 5 previos => 6 días
  WHERE cls.date >= DATE_SUB(DATE(b.last_upd), 5)
  {% else %}
  WHERE cls.date >= DATE '2024-01-01'
  {% endif %}
),

aggregated AS (
  SELECT
      date,
      CAST(date_format(date,'yyyyMMdd') AS INT)                 AS year_month_day_code,
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
           COALESCE(utm_ad_id, 'NULL'),
           COALESCE(utm_content, 'NULL'),
           COALESCE(utm_term, 'NULL'),
           COALESCE(first_event_device, 'NULL'),
           COALESCE(last_event_device, 'NULL'),
           COALESCE(CAST(only_login_session AS STRING), 'NULL'),
           COALESCE(CAST(login_in_session   AS STRING), 'NULL'),
           COALESCE(landing_page_type, 'NULL'),
           COALESCE(user_type, 'NULL'),
           COALESCE(session_status, 'NULL')
         )) AS row_hash
  FROM aggregated
)

SELECT 
  f.*,
  COALESCE(e.sys_audit_created_on, current_timestamp)       AS sys_audit_created_on,
  COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
  current_timestamp                                          AS sys_audit_updated_on,
  'data-dev-dbt-products'                                    AS sys_audit_updated_by
FROM final f
LEFT JOIN (
  {% if is_incremental() %}
  WITH b AS (
    SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01') AS last_upd
    FROM {{ this }}
  ),
  dd AS (
    SELECT EXPLODE(SEQUENCE(DATE_SUB(DATE(b.last_upd), 5), CURRENT_DATE)) AS d
    FROM b
  )
  SELECT row_hash, sys_audit_created_on, sys_audit_created_by
  FROM {{ this }}
  WHERE year_month_day_code IN (SELECT CAST(date_format(d,'yyyyMMdd') AS INT) FROM dd)
  {% else %}
  SELECT CAST(NULL AS STRING) AS row_hash,
         CAST(NULL AS TIMESTAMP) AS sys_audit_created_on,
         CAST(NULL AS STRING) AS sys_audit_created_by
  WHERE 1=0
  {% endif %}
) e
  ON f.row_hash = e.row_hash

