{{ config(
  materialized='incremental',
  incremental_strategy='merge',
  unique_key=['store_id'],
  partition_by=['year_month_day_code'],
  on_schema_change='fail',
  tags=['daily-9am','marketing'],
post_hook=["OPTIMIZE {{ this }} ZORDER BY (store_id, ms_contact_date)"]
 ) }}

-- 1) baseline para incremental
WITH baseline AS (
  {% if is_incremental() %}
  SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01') AS last_upd
  FROM {{ this }}
  {% else %}
  SELECT TIMESTAMP '1900-01-01' AS last_upd
  {% endif %}
),

-- 2) fuente (ephemeral)
src_all AS (
  SELECT * FROM {{ ref('_int__marketing_acquisition__project_ms__store') }}
),

-- 3) changed ids (lookback fijo sin vars/env)
{% set lookback = 7 %}
{{ marketing_mpt_changed_ids(
     last_upd_cte='baseline',
     lookback_days=lookback,
     sources=[
       {"sql": "select cast(store_id as bigint) store_id, max(sys_audit_updated_on) updated_on
                from " ~ ref('marketing__acquisition__project_ms_base__domain') ~ " group by 1"},
       {"sql": "select cast(store_id as bigint) store_id, sys_audit_updated_on as updated_on
                from " ~ ref('s__attributes__store_core__ref')},
       {"sql": "select cast(store_id as bigint) store_id, sys_audit_updated_on as updated_on
                from " ~ ref('s__lifecycle__store_status__ref')},
       {"sql": "select cast(store_id as bigint) store_id, max(sys_audit_updated_on) updated_on
                from " ~ ref('marketing_attribution_model') ~ " group by 1"}
     ]
) }}

, src AS (
  {% if is_incremental() %}
    SELECT s.* FROM src_all s INNER JOIN changed_ids c USING (store_id)
  {% else %}
    SELECT * FROM src_all
  {% endif %}
)

-- 4) claves y partición
, with_keys AS (
  SELECT
    s.*,
    {{ marketing_mpt_greatest_ts([
      'deps_ms_updated_on',
      'deps_sc_updated_on',
      'deps_lc_updated_on',
      'deps_at_updated_on'
    ]) }} AS deps_last_updated_on,
    COALESCE(
      CAST(ms_contact_date AS DATE),
      CAST(created_at AS DATE),
      first_disparo_date,
      first_visit_date
    ) AS partition_date,
    CAST(date_format(
      COALESCE(
        CAST(ms_contact_date AS DATE),
        CAST(created_at AS DATE),
        first_disparo_date,
        first_visit_date
      ), 'yyyyMMdd'
    ) AS INT) AS year_month_day_code
  FROM src s
)

-- 5) existing seguro 
, existing AS (
  {% if is_incremental() %}
    SELECT store_id, sys_audit_created_on, sys_audit_created_by
    FROM {{ this }}
  {% else %}
    SELECT
      CAST(NULL AS BIGINT)      AS store_id,
      CAST(NULL AS TIMESTAMP)   AS sys_audit_created_on,
      CAST(NULL AS STRING)      AS sys_audit_created_by
    WHERE 1=0
  {% endif %}
)

-- 6) auditoría + row hash
, final_rows AS (
  SELECT
    w.*,
    COALESCE(e.sys_audit_created_on, current_timestamp)         AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by,  'data-dev-dbt-marketing') AS sys_audit_created_by,
    current_timestamp                                            AS sys_audit_updated_on,
    'data-dev-dbt-marketing'                                     AS sys_audit_updated_by,

    {{ mpt_hash([
      'w.store_id',
      'w.has_ms_tag',
      'w.ms_reason',
      'w.ms_contact_date',
      'w.created_at',
      'w.partner_code',
      'w.new_seller_at',
      'w.first_payment',
      'w.churned_at',
      'w.domain',
      'w.emails',
      'w.phones',
      'w.instagram_url',
      'w.platform',
      'w.estimated_monthly_sales',
      'w.peso',
      'w.repeated_domain',
      'w.disparos',
      'w.disparo_date',
      'w.mapping_method',
      'w.first_disparo_date',
      'w.first_visit_ts',
      'w.first_visit_date',
      'w.deps_ms_updated_on',
      'w.deps_sc_updated_on',
      'w.deps_lc_updated_on',
      'w.deps_at_updated_on',
      'w.deps_last_updated_on',
      'w.year_month_day_code'
    ]) }} AS row_hash
  FROM with_keys w
  LEFT JOIN existing e USING (store_id)
)

SELECT * FROM final_rows
