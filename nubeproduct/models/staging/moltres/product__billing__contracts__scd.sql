{{
    config(
        materialized='incremental',
        incremental_strategy = 'merge',
        unique_key='id',
        on_schema_change='fail',
        tags = ['product','daily-6am']
    )
}}

WITH source AS (
    SELECT 
        mc.id,
        mc.store_id,
        mc.plan_id,
        mc.type,
        mc.description,
        mc.start_date,
        mc.end_date,
        mc.created_at,
        mc.deleted_at,
        mc.total,
        mc.sys_audit_updated_on
    FROM {{ source('stg_moltres', 'mwp_contracts') }} AS mc

    {% if is_incremental() %}
      -- Traz apenas contratos que foram atualizados desde a última execução
      WHERE mc.sys_audit_updated_on >= (
        SELECT COALESCE(MAX(sys_audit_updated_on), '1900-01-01') FROM {{ this }}
      )
    {% endif %}
),

existing_data AS (
    {{ get_existing_data(this, ['id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
    source.id,
    source.store_id,
    source.plan_id,
    source.type,
    source.description AS description_contract,
    source.start_date,
    source.end_date,
    source.created_at,
    source.deleted_at,
    source.total,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM source
LEFT JOIN existing_data e 
  ON source.id = e.id