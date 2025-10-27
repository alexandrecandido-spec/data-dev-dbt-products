-- depends_on: {{ ref('_int_marketing__ga4_sessions_attribution') }}

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
      -- Borra SOLO las últimas 6 particiones (hoy + 5 previas)
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

{# =========================
   Cols existentes en target
   ========================= #}
{% set rel = adapter.get_relation(
    database=this.database,
    schema=this.schema,
    identifier=this.identifier
) %}
{% if rel %}
  {% set existing_cols = adapter.get_columns_in_relation(rel) | map(attribute='name') | map('lower') | list %}
{% else %}
  {% set existing_cols = [] %}
{% endif %}

WITH
/* -----------------------------------------
   0) Auditoría histórica mínima (created_on/by)
   ----------------------------------------- */
existing_data_audit AS (
  {{ get_existing_data(this, [
      'row_hash',
      'sys_audit_created_on',
      'sys_audit_created_by',
      'year_month_day_code'
  ]) }}
),

/* -----------------------------------------
   0.1) Insumos históricos para el macro input_changed
        (normalizamos dp_input_sources -> string)
   ----------------------------------------- */
existing_inputs_for_macro AS (
  {% if 'dp_input_sources' in existing_cols %}
    SELECT
      row_hash,
      COALESCE(CONCAT_WS(',', dp_input_sources), '') AS input_sources
    FROM {{ this }}
  {% else %}
    -- si es el primer run y no existe la col, dejamos vacío
    SELECT CAST(NULL AS STRING) AS row_hash,
           CAST(NULL AS STRING) AS input_sources
    WHERE 1=0
  {% endif %}
)

{% if is_incremental() %}
, last_upd AS (
  SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01') AS max_upd
  FROM {{ this }}
)
, last_dc AS (
  SELECT COALESCE(MAX(year_month_day_code), 19000101) AS max_dc
  FROM {{ this }}
)
, base_days AS (
  -- hoy + 5 previos (6 días)
  SELECT CAST(date_format(d,'yyyyMMdd') AS INT) AS dc
  FROM (
    SELECT EXPLODE(SEQUENCE(
      DATE_SUB(DATE(TO_DATE(CAST((SELECT max_dc FROM last_dc) AS STRING), 'yyyyMMdd')), 5),
      CURRENT_DATE
    )) AS d
  )
)
{% endif %}

/* -----------------------------------------
   1) Fuente INTERMEDIATE (ya dedupeada y con dp_row_hash)
   alias = main_source (requerido por el macro)
   ----------------------------------------- */
, main_source AS (
  SELECT *
  FROM {{ ref('_int_marketing__ga4_sessions_attribution') }}
  {% if not is_incremental() %}
    WHERE date >= DATE '2024-01-01'
  {% endif %}
)

/* -----------------------------------------
   2) Filtro incremental:
      - últimos 6 días
      - o change_timestamp_incremental >= last_upd
      - o cambios de inputs (macro input_changed)
   ----------------------------------------- */
, candidate_rows AS (
  SELECT main_source.*
  FROM main_source main_source
  LEFT JOIN existing_inputs_for_macro e
    ON e.row_hash = main_source.dp_row_hash
  {% if is_incremental() %}
  WHERE
        CAST(date_format(main_source.date,'yyyyMMdd') AS INT) IN (SELECT dc FROM base_days)
     OR main_source.change_timestamp_incremental >= (SELECT max_upd FROM last_upd)
     OR {{ input_changed('utm') }}
     OR {{ input_changed('subteam') }}
     OR {{ input_changed('referrer') }}
     OR {{ input_changed('url') }}
     OR {{ input_changed('insti') }}
     OR {{ input_changed('partner_exception') }}
     OR {{ input_changed('affiliate_classification') }}
     OR {{ input_changed('partner_code') }}
  {% else %}
  WHERE main_source.date >= DATE '2024-01-01'
  {% endif %}
)

SELECT
  c.year_month_day_code,
  c.date,
  c.source_ga4_classification,
  c.original_user_country,
  c.classified_country,
  c.env,
  c.landing_page,
  c.landing_page_domain,
  c.landing_page_path,
  c.last_source,
  c.last_medium,
  c.last_campaign,
  c.first_event_device,
  c.last_event_device,
  c.only_login_session,
  c.login_in_session,
  c.landing_page_type,
  c.user_type,
  c.session_status,
  c.utm_ad_id,
  c.utm_content,
  c.utm_term,
  c.partner_code,

  /* atributos del intermediate */
  c.url_owner,
  c.url_content_type,
  c.insti_pages,
  c.insti_page_groups,
  c.type_of_page,
  c.organic_results,

  /* clasificación final */
  c.mkt_source,
  COALESCE(c.mkt_subteam, c.mkt_source) AS mkt_subteam,

  /* métricas */
  c.distinct_user_count,
  c.distinct_session_count,
  c.total_trials,
  c.total_payments,
  c.total_engagements,
  c.avg_session_duration,
  c.median_session_duration,
  c.avg_pageviews_per_session,
  c.median_pageviews_per_session,

  /* compat: exponer insumos + ts */
  c.input_sources                AS dp_input_sources,
  c.change_timestamp_incremental AS dp_change_timestamp_incremental,

  /* merge key único = hash que viene del INT */
  c.dp_row_hash                  AS row_hash,

  /* auditoría */
  COALESCE(a.sys_audit_created_on, current_timestamp)       AS sys_audit_created_on,
  COALESCE(a.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
  current_timestamp                                          AS sys_audit_updated_on,
  'data-dev-dbt-products'                                    AS sys_audit_updated_by

FROM candidate_rows c
LEFT JOIN existing_data_audit a
  ON a.row_hash = c.dp_row_hash
{% if is_incremental() %}
  AND a.year_month_day_code = c.year_month_day_code
{% endif %}



