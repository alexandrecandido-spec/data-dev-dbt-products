-- depends_on: {{ ref('ga4__event_info') }}
-- depends_on: {{ ref('ga4__mod_pv_info') }}
-- depends_on: {{ ref('ga4__tp_info') }}
-- depends_on: {{ ref('ga4__session_info') }}
-- depends_on: {{ ref('_int_marketing__ga4_sessions_with_dimensions') }}

{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    partition_by=['year_month_day_code'],
    unique_key=['year_month_day_code','unique_session'],
    on_schema_change='fail',
    tags=['daily-6am']
) }}

-- 1) Baseline del DP (último updated_on)
WITH baseline AS (
  {% if is_incremental() %}
  SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01 00:00:00') AS last_dp_update
  FROM {{ this }}
  {% else %}
  SELECT TIMESTAMP '1900-01-01 00:00:00' AS last_dp_update
  {% endif %}
),

-- 2) Fechas impactadas por updates en staging (con solape 5')
impacted_dates AS (
  {% if is_incremental() %}
  SELECT DISTINCT d FROM (
    SELECT e.event_date         AS d FROM {{ ref('ga4__event_info') }}   e, baseline b
     WHERE e.sys_audit_updated_on >= b.last_dp_update - INTERVAL 5 MINUTES
     AND e.year_month_day_code >= CAST(date_format(date_sub(date(b.last_dp_update), 30),'yyyyMMdd') AS INT) -- opcional, ayuda al pruning
    UNION ALL
    SELECT m.event_date         AS d FROM {{ ref('ga4__mod_pv_info') }} m, baseline b
     WHERE m.sys_audit_updated_on >= b.last_dp_update - INTERVAL 5 MINUTES
     AND m.year_month_day_code >= CAST(date_format(date_sub(date(b.last_dp_update), 30),'yyyyMMdd') AS INT)
    UNION ALL
    SELECT t.event_date         AS d FROM {{ ref('ga4__tp_info') }}     t, baseline b
     WHERE t.sys_audit_updated_on >= b.last_dp_update - INTERVAL 5 MINUTES
     AND t.year_month_day_code >= CAST(date_format(date_sub(date(b.last_dp_update), 30),'yyyyMMdd') AS INT)
    UNION ALL
    SELECT s.start_session_date AS d FROM {{ ref('ga4__session_info') }} s, baseline b
     WHERE s.sys_audit_updated_on >= b.last_dp_update - INTERVAL 5 MINUTES
     AND s.year_month_day_code >= CAST(date_format(date_sub(date(b.last_dp_update), 30),'yyyyMMdd') AS INT)
  )
  {% else %}
  SELECT DATE '1900-01-01' AS d WHERE FALSE
  {% endif %}
),

-- 3) Particiones target a tocar (impactadas + ventana 7 días)
target_partitions AS (
  {% if is_incremental() %}
  SELECT DISTINCT CAST(date_format(d,'yyyyMMdd') AS INT) AS ymd
  FROM impacted_dates
  UNION
  SELECT DISTINCT CAST(date_format(date_sub(current_date, n),'yyyyMMdd') AS INT) AS ymd
  FROM (SELECT posexplode(sequence(0, 6)) AS (n, _)) tmp   -- últimos 7 días
  {% else %}
  SELECT 0 AS ymd WHERE FALSE
  {% endif %}
),

-- 4) existing_data SOLO de las particiones a tocar 
existing_data AS (
  {% if is_incremental() %}
  SELECT year_month_day_code, unique_session, sys_audit_created_on, sys_audit_created_by
  FROM {{ this }}
  WHERE year_month_day_code IN (SELECT ymd FROM target_partitions)
  {% else %}
  SELECT CAST(NULL AS INT) AS year_month_day_code,
         CAST(NULL AS STRING) AS unique_session,
         CAST(NULL AS TIMESTAMP) AS sys_audit_created_on,
         CAST(NULL AS STRING) AS sys_audit_created_by
  WHERE 1=0
  {% endif %}
),

-- 5) Fuente limitada (fechas impactadas + ventana 7 días)
src AS (
  SELECT
      date,
      CAST(date_format(date,'yyyyMMdd') AS INT) AS year_month_day_code,
      source_ga4_classification,
      original_user_country,
      env,
      landing_page,
      landing_page_domain,
      landing_page_path,
      landing_page_type,
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
      user_type,
      engage,
      user_pseudo_id,
      unique_session,
      trial,
      payment,
      session_duration_minutes,
      pageviews_per_session
  FROM {{ ref('_int_marketing__ga4_sessions_with_dimensions') }}
  {% if is_incremental() %}
    WHERE date IN (SELECT d FROM impacted_dates)
       OR date >= date_sub(current_date, 7)
  {% else %}
    WHERE date >= DATE '2024-01-01'
  {% endif %}
)

-- 6) Select final + clasificación país 
SELECT
  src.*,
  CASE
    WHEN lower(coalesce(source_ga4_classification,'')) = 'inst-br'
         AND (
           lower(coalesce(landing_page_domain,'')) LIKE '%tiendanube%'
           OR  lower(coalesce(landing_page,''))     LIKE '%tiendanube.com%'
         )
      THEN CASE
             WHEN original_user_country = 'Argentina' THEN 'AR'
             WHEN original_user_country = 'Mexico'    THEN 'MX'
             WHEN original_user_country = 'Chile'     THEN 'CL'
             WHEN original_user_country = 'Colombia'  THEN 'CO'
             ELSE 'Other'
           END
    WHEN lower(coalesce(source_ga4_classification,'')) <> 'inst-br'
         AND (
           lower(coalesce(landing_page_domain,'')) LIKE '%nuvemshop%'
           OR  lower(coalesce(landing_page,''))     LIKE '%nuvemshop.com%'
         )
      THEN 'BR'
    WHEN date <= DATE '2024-09-07' THEN
      CASE
        WHEN lower(coalesce(source_ga4_classification,'')) = 'inst-br'
             OR (
               lower(coalesce(source_ga4_classification,'')) NOT LIKE '%inst%'
               AND (
                 lower(coalesce(landing_page_domain,'')) LIKE '%nuvemshop%'
                 OR  lower(coalesce(landing_page,''))     LIKE '%nuvemshop.com%'
               )
             ) THEN 'BR'
        WHEN lower(coalesce(source_ga4_classification,'')) = 'inst-ar' THEN 'AR'
        WHEN lower(coalesce(source_ga4_classification,'')) = 'inst-mx' THEN 'MX'
        WHEN lower(coalesce(source_ga4_classification,'')) = 'inst-co' THEN 'CO'
        WHEN lower(coalesce(source_ga4_classification,'')) = 'inst-cl' THEN 'CL'
        WHEN lower(coalesce(source_ga4_classification,'')) NOT LIKE '%inst%' AND original_user_country = 'Argentina' THEN 'AR'
        WHEN lower(coalesce(source_ga4_classification,'')) NOT LIKE '%inst%' AND original_user_country = 'Mexico'    THEN 'MX'
        WHEN lower(coalesce(source_ga4_classification,'')) NOT LIKE '%inst%' AND original_user_country = 'Chile'     THEN 'CL'
        WHEN lower(coalesce(source_ga4_classification,'')) NOT LIKE '%inst%' AND original_user_country = 'Colombia'  THEN 'CO'
        ELSE 'Other'
      END
    ELSE
      CASE
        WHEN lower(coalesce(source_ga4_classification,'')) = 'inst-br'
             OR (
               lower(coalesce(landing_page_domain,'')) LIKE '%nuvemshop%'
               OR  lower(coalesce(landing_page,''))     LIKE '%nuvemshop.com%'
             ) THEN 'BR'
        WHEN original_user_country = 'Argentina' THEN 'AR'
        WHEN original_user_country = 'Mexico'    THEN 'MX'
        WHEN original_user_country = 'Chile'     THEN 'CL'
        WHEN original_user_country = 'Colombia'  THEN 'CO'
        ELSE 'Other'
      END
  END AS classified_country,

  COALESCE(e.sys_audit_created_on, current_timestamp)       AS sys_audit_created_on,
  COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
  current_timestamp                                          AS sys_audit_updated_on,
  'data-dev-dbt-products'                                    AS sys_audit_updated_by
FROM src
LEFT JOIN existing_data e
  ON  src.year_month_day_code = e.year_month_day_code
  AND src.unique_session      = e.unique_session
