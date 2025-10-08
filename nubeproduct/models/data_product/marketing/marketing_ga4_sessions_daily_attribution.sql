-- depends_on: {{ ref('_int_marketing__ga4_sessions_attribution') }}
-- depends_on: {{ ref('inputs_marketing_attribution') }}

{{ config(
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
      -- Borra SOLO las últimas 6 particiones (hoy + 5 previas) vía MERGE DELETE
      MERGE INTO {{ this }} AS t
      USING (
        WITH maxdc AS (
          SELECT COALESCE(MAX(year_month_day_code), 19000101) AS max_dc
          FROM {{ this }}
        ),
        bounds AS (
          SELECT 
            DATE_SUB(TO_DATE(CAST(max_dc AS STRING), 'yyyyMMdd'), 5) AS d_from,
            CURRENT_DATE                                             AS d_to
          FROM maxdc
        )
        SELECT CAST(date_format(d,'yyyyMMdd') AS INT) AS dc
        FROM bounds
        LATERAL VIEW explode(sequence(d_from, d_to)) s AS d
      ) AS dd
      ON t.year_month_day_code = dd.dc
      WHEN MATCHED THEN DELETE;
    {% endif %}
    "
  ]
) }}

WITH
-- 0) existing_data (para auditoría y detección de días impactados)
existing_data_full AS (
  {{ get_existing_data(this, [
      'row_hash',
      'sys_audit_created_on',
      'sys_audit_created_by',
      'dp_input_sources',     
      'year_month_day_code'
  ]) }}
),
existing_data_audit AS (
  SELECT
    row_hash,
    sys_audit_created_on,
    sys_audit_created_by,
    year_month_day_code
  FROM existing_data_full
)

{% if is_incremental() %}
-- 1) Días a reconstruir (hoy + 5 previos) y detección de cambios
, last_dc AS (
  SELECT COALESCE(MAX(year_month_day_code), 19000101) AS max_dc
  FROM {{ this }}
)
, base_days AS (
  SELECT CAST(date_format(d,'yyyyMMdd') AS INT) AS dc
  FROM (
    SELECT EXPLODE(SEQUENCE(
      DATE_SUB(DATE(TO_DATE(CAST((SELECT max_dc FROM last_dc) AS STRING), 'yyyyMMdd')), 5),
      CURRENT_DATE
    )) AS d
  )
)
, last_upd AS (
  SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01') AS max_upd
  FROM {{ this }}
)
, inputs_newer AS (
  SELECT
    CASE WHEN
      (SELECT COALESCE(MAX(updated_at), TIMESTAMP '1900-01-01') FROM {{ ref('inputs_marketing_attribution') }})
      >
      (SELECT max_upd FROM last_upd)
    THEN 1 ELSE 0 END AS needs_reattrib
)
, impacted_days AS (
  -- Construimos el STRING que espera el macro a partir de dp_input_sources del histórico
  SELECT DISTINCT e.year_month_day_code AS dc
  FROM (
    SELECT
      row_hash,
      sys_audit_created_on,
      sys_audit_created_by,
      year_month_day_code,
      -- si dp_input_sources es array<string>, lo aplanamos; si es null, devolvemos ''
      COALESCE(CONCAT_WS(',', dp_input_sources), '') AS input_sources
    FROM existing_data_full
  ) e
  LEFT JOIN (
    SELECT
      row_hash,
      COALESCE(CONCAT_WS(',', dp_input_sources), '') AS input_sources
    FROM existing_data_full
  ) main_source
    ON main_source.row_hash = e.row_hash
  JOIN inputs_newer n ON n.needs_reattrib = 1
  WHERE
      {{ input_changed('utm') }}
   OR {{ input_changed('subteam') }}
   OR {{ input_changed('referrer') }}
   OR {{ input_changed('url') }}
   OR {{ input_changed('insti') }}
   OR {{ input_changed('partner_exception') }}
   OR {{ input_changed('affiliate_classification') }}
   OR {{ input_changed('partner_code') }}
)
, days_by_change_ts AS (
  -- Días donde el INTERMEDIATE trae cambios nuevos
  SELECT DISTINCT CAST(date_format(date,'yyyyMMdd') AS INT) AS dc
  FROM {{ ref('_int_marketing__ga4_sessions_attribution') }}
  WHERE change_timestamp_incremental >= (SELECT max_upd FROM last_upd)
)
, selected_days AS (
  SELECT dc FROM base_days
  UNION SELECT dc FROM impacted_days
  UNION SELECT dc FROM days_by_change_ts
)
{% endif %}

-- 2) Fuente (intermediate) acotada por selected_days en incremental
, source_int AS (
  SELECT *
  FROM {{ ref('_int_marketing__ga4_sessions_attribution') }}
  {% if is_incremental() %}
  WHERE CAST(date_format(date,'yyyyMMdd') AS INT) IN (SELECT dc FROM selected_days)
  {% else %}
  WHERE date >= DATE '2024-01-01'
  {% endif %}
)

-- 3) Hash (DP)
, final_with_hash AS (
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
)

, filtered AS (
  SELECT f.*
  FROM final_with_hash f
  {% if is_incremental() %}
  WHERE f.year_month_day_code IN (SELECT dc FROM selected_days)
  {% else %}
  WHERE f.date >= DATE '2024-01-01'
  {% endif %}
)

-- 4) SELECT final + auditoría
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

  /* compat: publicamos input_sources con nombre histórico */
  f.input_sources AS dp_input_sources,
  f.change_timestamp_incremental AS dp_change_timestamp_incremental,

  /* row_hash (DP) para el MERGE */
  f.dp_row_hash AS row_hash,

  /* auditoría */
  COALESCE(e.sys_audit_created_on, current_timestamp)       AS sys_audit_created_on,
  COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
  current_timestamp                                          AS sys_audit_updated_on,
  'data-dev-dbt-products'                                    AS sys_audit_updated_by

FROM filtered f
LEFT JOIN existing_data_audit e
  ON e.row_hash = f.dp_row_hash
{% if is_incremental() %}
  AND e.year_month_day_code IN (SELECT dc FROM selected_days)
{% endif %}


