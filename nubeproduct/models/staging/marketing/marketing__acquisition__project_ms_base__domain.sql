{{ config(
  materialized='incremental',
  incremental_strategy='merge',
  unique_key=['domain'],                   
  partition_by=['year_month_day_code'],
  on_schema_change='fail',
  tags=['daily-9am','marketing']
) }}

WITH existing AS (
  {% if is_incremental() %}
  SELECT
    domain,                         
    row_hash,
    sys_audit_created_on,
    sys_audit_created_by
  FROM {{ this }}
  {% else %}
  SELECT
    CAST(NULL AS {{ dbt.type_string() }}) AS domain,
    CAST(NULL AS {{ dbt.type_string() }}) AS row_hash,
    CAST(NULL AS TIMESTAMP)               AS sys_audit_created_on,
    CAST(NULL AS {{ dbt.type_string() }}) AS sys_audit_created_by
  WHERE 1=0
  {% endif %}
),

-- 1) UNION de ambas sheets (normalizado)
base AS (
  SELECT
    lower(trim(domain))                                       AS domain,
    emails,
    phones,
    instagram_url,
    lower(trim(platform))                                     AS platform,
    CAST(REPLACE(estimated_monthly_sales, ',', '') AS DOUBLE) AS estimated_monthly_sales,
    CAST(peso AS DOUBLE)                                      AS peso,
    CAST(repeated_domain AS {{ dbt.type_string() }})          AS repeated_domain,
    CAST(disparos AS INT)                                     AS disparos,
    CAST(disparo_date AS DATE)                                AS disparo_date
  FROM {{ source('stg_unity_data_manual','ext__marketing__acquisition__merchant_sellers_base_total_a_s') }}
  WHERE domain IS NOT NULL AND trim(domain) <> ''
  UNION ALL
  SELECT
    lower(trim(domain)),
    emails,
    phones,
    instagram_url,
    lower(trim(platform)),
    CAST(REPLACE(estimated_monthly_sales, ',', '') AS DOUBLE),
    CAST(peso AS DOUBLE),
    CAST(repeated_domain AS {{ dbt.type_string() }}),
    CAST(disparos AS INT),
    CAST(disparo_date AS DATE)
  FROM {{ source('stg_unity_data_manual','ext__marketing__acquisition__merchant_sellers_base_total_t_z') }}
  WHERE domain IS NOT NULL AND trim(domain) <> ''
),

-- 2) DEDUPE después del UNION: 1 fila por domain
--    Regla: con fecha primero; si hay varias con fecha, la de fecha mínima;
--    si ninguna tiene fecha, desempate determinístico.
ranked AS (
  SELECT
    b.*,
    ROW_NUMBER() OVER (
      PARTITION BY b.domain
      ORDER BY
        CASE WHEN b.disparo_date IS NOT NULL THEN 0 ELSE 1 END,
        b.disparo_date ASC,
        COALESCE(b.platform,'')       ASC,
        COALESCE(b.emails,'')         ASC,
        COALESCE(b.phones,'')         ASC,
        COALESCE(b.instagram_url,'')  ASC
    ) AS rn
  FROM base b
),

picked AS (
  SELECT *
  FROM ranked
  WHERE rn = 1
),

-- 3) Mapping domain → store_id (exacto → clean)
store_info AS (
  SELECT
    CAST(store_id AS BIGINT)                       AS store_id,
    lower(trim(domain))                            AS tn_domain,
    split_part(lower(trim(domain)),'.',1)          AS tn_domain_clean
  FROM {{ ref('s__attributes__store_core__ref') }}
),

map_store AS (
  SELECT
    p.*,
    split_part(p.domain, '.', 1)                   AS ext_domain_clean,
    si_exact.store_id                              AS store_id_exact,
    si_clean.store_id                              AS store_id_clean
  FROM picked p
  LEFT JOIN store_info si_exact
    ON p.domain = si_exact.tn_domain
  LEFT JOIN store_info si_clean
    ON si_exact.store_id IS NULL
   AND split_part(p.domain,'.',1) = si_clean.tn_domain_clean
),

resolved AS (
  SELECT
    m.*,
    COALESCE(m.store_id_exact, m.store_id_clean) AS store_id,
    CASE
      WHEN m.store_id_exact IS NOT NULL THEN 'domain_exact'
      WHEN m.store_id_clean IS NOT NULL THEN 'domain_clean'
      ELSE 'none'
    END AS mapping_method
  FROM map_store m
),

-- 4) Partición (si no hay disparo_date, usamos hoy para no dejar NULL)
with_keys AS (
  SELECT
    r.*,
    CAST(date_format(COALESCE(r.disparo_date, current_date),'yyyyMMdd') AS INT) AS year_month_day_code
  FROM resolved r
),

-- 5) row_hash con TODOS los campos de negocio (sin auditoría/partición)
with_hash AS (
  SELECT
    wk.*,
    {{ mpt_hash([
      "wk.store_id", "wk.mapping_method",
      "wk.domain", "wk.platform",
      "CAST(wk.estimated_monthly_sales AS DECIMAL(38,6))",
      "CAST(wk.peso AS DECIMAL(38,6))",
      "CAST(wk.disparos AS " ~ dbt.type_string() ~ ")",
      "CAST(wk.repeated_domain AS " ~ dbt.type_string() ~ ")",
      "wk.emails", "wk.phones", "wk.instagram_url",
      "CAST(wk.disparo_date AS DATE)"
    ]) }} AS row_hash
  FROM with_keys wk
),

-- 6) Upsert solo si es nuevo o cambió algo (preservamos created_*)
to_upsert AS (
  SELECT
    wh.*,
    COALESCE(e.sys_audit_created_on, current_timestamp)         AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by,  'data-dev-dbt-marketing') AS sys_audit_created_by,
    current_timestamp                                            AS sys_audit_updated_on,
    'data-dev-dbt-marketing'                                     AS sys_audit_updated_by
  FROM with_hash wh
  LEFT JOIN existing e
    ON e.domain = wh.domain
  WHERE e.row_hash IS NULL OR e.row_hash <> wh.row_hash
)

SELECT
  store_id, mapping_method,
  domain,
  emails, phones, instagram_url,
  platform, estimated_monthly_sales, peso, repeated_domain,
  disparos, disparo_date,
  year_month_day_code,
  sys_audit_created_on, sys_audit_created_by,
  sys_audit_updated_on, sys_audit_updated_by,
  row_hash
FROM to_upsert
