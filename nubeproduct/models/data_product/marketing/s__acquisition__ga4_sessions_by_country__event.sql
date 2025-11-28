-- depends_on: {{ ref('_int_marketing__ga4_sessions_with_dimensions') }}

{{ config(
  materialized         = 'incremental',
  incremental_strategy = 'merge',
  partition_by         = ['year_month_day_code'],
  unique_key           = ['year_month_day_code','unique_session'],
  on_schema_change     = 'fail',
  tags                 = ['daily-6am'],
  pre_hook = [
    "{% if is_incremental() %}
       -- Borrar particiones desde (MAX updated_on - 5 días) hasta hoy
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
     {% endif %}"
  ]
) }}

WITH baseline AS (
  {% if is_incremental() %}
  SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01') AS last_upd
  FROM {{ this }}
  {% else %}
  SELECT TIMESTAMP '1900-01-01' AS last_upd
  {% endif %}
),

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
  FROM {{ ref('_int_marketing__ga4_sessions_with_dimensions') }} cls
  CROSS JOIN baseline b
  {% if is_incremental() %}
  WHERE cls.date >= DATE_SUB(DATE(b.last_upd), 5)
  {% else %}
  WHERE cls.date >= DATE '2024-01-01'
  {% endif %}
)

SELECT
  src.*,
CASE
  WHEN date <= DATE '2024-09-07' THEN
    CASE
      WHEN source_ga4_classification = 'inst-br'
           OR (source_ga4_classification NOT LIKE '%inst%'
               AND landing_page LIKE '%nuvemshop%')                                       THEN 'BR'
      WHEN source_ga4_classification = 'inst-ar'                                          THEN 'AR'
      WHEN source_ga4_classification = 'inst-mx'                                          THEN 'MX'
      WHEN source_ga4_classification = 'inst-co'                                          THEN 'CO'
      WHEN source_ga4_classification = 'inst-cl'                                          THEN 'CL'
      WHEN source_ga4_classification NOT LIKE '%inst%' AND original_user_country = 'Argentina' THEN 'AR'
      WHEN source_ga4_classification NOT LIKE '%inst%' AND original_user_country = 'Mexico'    THEN 'MX'
      WHEN source_ga4_classification NOT LIKE '%inst%' AND original_user_country = 'Chile'     THEN 'CL'
      WHEN source_ga4_classification NOT LIKE '%inst%' AND original_user_country = 'Colombia'  THEN 'CO'
      WHEN source_ga4_classification NOT LIKE '%inst%' AND original_user_country NOT IN
           ('Brazil','Mexico','Argentina','Chile','Colombia')                               THEN 'Other'
      ELSE original_user_country
    END

  ELSE
    /* >= cutoff: primero inst-br -> BR, luego Tiendanube paths MX/CO/CL, luego original_user_country */
    CASE
      /* 1) inst-br post-cutoff sigue yendo a BR */
      WHEN LOWER(COALESCE(source_ga4_classification,'')) = 'inst-br' THEN 'BR'

      /* 2) Tiendanube.com con prefijos de país -> MX/CO/CL */
      WHEN LOWER(COALESCE(landing_page_domain,'')) LIKE '%tiendanube.com%'
           AND LOWER(COALESCE(landing_page_path,'')) LIKE '/mx%'                         THEN 'MX'
      WHEN LOWER(COALESCE(landing_page_domain,'')) LIKE '%tiendanube.com%'
           AND LOWER(COALESCE(landing_page_path,'')) LIKE '/co%'                         THEN 'CO'
      WHEN LOWER(COALESCE(landing_page_domain,'')) LIKE '%tiendanube.com%'
           AND LOWER(COALESCE(landing_page_path,'')) LIKE '/cl%'                         THEN 'CL'

      /* 3) Fallback por original_user_country (igual a tu lógica original post-cutoff) */
      WHEN original_user_country = 'Argentina'                                            THEN 'AR'
      WHEN original_user_country = 'Mexico'                                               THEN 'MX'
      WHEN original_user_country = 'Chile'                                                THEN 'CL'
      WHEN original_user_country = 'Colombia'                                             THEN 'CO'
      WHEN original_user_country NOT IN ('Mexico','Argentina','Chile','Colombia')         THEN 'Other'
      ELSE original_user_country
    END
END AS classified_country,

  COALESCE(e.sys_audit_created_on, current_timestamp)       AS sys_audit_created_on,
  COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
  current_timestamp                                          AS sys_audit_updated_on,
  'data-dev-dbt-products'                                    AS sys_audit_updated_by

FROM src
LEFT JOIN (
  {% if is_incremental() %}
  SELECT year_month_day_code, unique_session, sys_audit_created_on, sys_audit_created_by
  FROM {{ this }}
  WHERE year_month_day_code IN (
    SELECT CAST(date_format(d,'yyyyMMdd') AS INT)
    FROM (
      SELECT EXPLODE(SEQUENCE(DATE_SUB(DATE((SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01') FROM {{ this }})), 5),
                               CURRENT_DATE)) AS d
    )
  )
  {% else %}
  SELECT CAST(NULL AS INT) AS year_month_day_code,
         CAST(NULL AS STRING) AS unique_session,
         CAST(NULL AS TIMESTAMP) AS sys_audit_created_on,
         CAST(NULL AS STRING) AS sys_audit_created_by
  WHERE 1=0
  {% endif %}
) e
  ON  src.year_month_day_code = e.year_month_day_code
  AND src.unique_session      = e.unique_session

