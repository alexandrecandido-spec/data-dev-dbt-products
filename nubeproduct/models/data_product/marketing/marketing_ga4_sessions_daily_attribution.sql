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
  {{ get_existing_data(this, [
      'row_hash',
      'sys_audit_created_on',
      'sys_audit_created_by',
      'input_sources',
      'year_month_day_code'
  ]) }}
),

source_int AS (
  SELECT *
  FROM {{ ref('_int_marketing__ga4_sessions_attribution') }}
),

final_with_hash AS (
  SELECT
    s.*,
    md5(CONCAT_WS('||',
      CAST(s.year_month_day_code AS STRING),
      CAST(s.date AS STRING),
      COALESCE(s.source_ga4_classification,''),
      COALESCE(s.original_user_country,''),
      COALESCE(s.env,''),
      COALESCE(s.landing_page,''),
      COALESCE(s.landing_page_domain,''),
      COALESCE(s.landing_page_path,''),
      COALESCE(s.last_source,''),
      COALESCE(s.last_medium,''),
      COALESCE(s.last_campaign,''),
      COALESCE(s.utm_ad_id,''),
      COALESCE(s.utm_content,''),
      COALESCE(s.utm_term,''),
      COALESCE(s.first_event_device,''),
      COALESCE(s.last_event_device,''),
      COALESCE(CAST(s.only_login_session AS STRING),''),
      COALESCE(CAST(s.login_in_session AS STRING),''),
      COALESCE(s.landing_page_type,''),
      COALESCE(s.user_type,''),
      COALESCE(s.session_status,''),
      COALESCE(s.partner_code,'')
    )) AS dp_row_hash
  FROM source_int s
),

filtered AS (
  SELECT f.*
  FROM final_with_hash f
  {% if is_incremental() %}
    WHERE (
      /* 1) rolling 5 días respecto a lo ya cargado */
      f.year_month_day_code >= (
        SELECT COALESCE(MAX(year_month_day_code), 19000101)
        FROM {{ this }}
      ) - 5

      /* 2) cambios en inputs (creación/edición/cierre) */
      OR f.change_timestamp_incremental >= (
        SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01')
        FROM {{ this }}
      )

      /* 3) toggles de inputs (macro input_changed) */
      OR EXISTS (
        SELECT 1
        FROM existing_data e
        CROSS JOIN (SELECT f.input_sources) AS main_source(input_sources)  -- alias requerido por el macro
        WHERE e.row_hash = f.dp_row_hash
          AND (
            {{ input_changed('utm') }}
            OR {{ input_changed('subteam') }}
            OR {{ input_changed('referrer') }}
            OR {{ input_changed('url') }}
            OR {{ input_changed('insti') }}
            OR {{ input_changed('partner_exception') }}
            OR {{ input_changed('affiliate_classification') }}
            OR {{ input_changed('partner_code') }}
          )
      )
    )
  {% else %}
    WHERE f.date >= DATE '2024-01-01'
  {% endif %}
)

SELECT
  f.year_month_day_code,
  f.date,
  f.source_ga4_classification,
  f.original_user_country,
  f.classified_country,
  f.env,
  f.landing_page,
  f.landing_page_domain,
  f.landing_page_path,
  f.last_source,
  f.last_medium,
  f.last_campaign,
  f.first_event_device,
  f.last_event_device,
  f.only_login_session,
  f.login_in_session,
  f.landing_page_type,
  f.user_type,
  f.session_status,
  f.utm_ad_id,
  f.utm_content,
  f.utm_term,

  /* nuevo campo expuesto */
  f.partner_code,

  /* atributos del intermediate */
  f.url_owner,
  f.url_content_type,
  f.insti_pages,
  f.insti_page_groups,
  f.type_of_page,
  f.organic_results,

  /* clasificación final */
  f.mkt_source,
  COALESCE(f.mkt_subteam, f.mkt_source) AS mkt_subteam,

  /* métricas */
  f.distinct_user_count,
  f.distinct_session_count,
  f.total_trials,
  f.total_payments,
  f.total_engagements,
  f.avg_session_duration,
  f.median_session_duration,
  f.avg_pageviews_per_session,
  f.median_pageviews_per_session,

  /* helpers incremental */
  f.input_sources,
  f.change_timestamp_incremental,

  /* row_hash (DP) para el MERGE */
  f.dp_row_hash AS row_hash,

  /* auditoría */
  COALESCE(e.sys_audit_created_on, current_timestamp)       AS sys_audit_created_on,
  COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
  current_timestamp                                          AS sys_audit_updated_on,
  'data-dev-dbt-products'                                    AS sys_audit_updated_by

FROM filtered f
LEFT JOIN existing_data e
  ON e.row_hash = f.dp_row_hash
