{{
    config(
        materialized='incremental',
        unique_key='id',
        on_schema_change='fail',
        tags = ['weekly-monday-10am']
    )
}}

WITH source AS (
    SELECT 
        id,
        store_id,
        plan_id,
        created_at,
        start_date,
        end_date,
        type,
        total,
        sys_audit_updated_on
    FROM {{ source('stg_moltres', 'mwp_contracts') }}

    {% if is_incremental() %}
      -- Traz apenas contratos que foram atualizados desde a última execução
      WHERE sys_audit_updated_on >= (
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
    source.created_at,
    source.start_date,
    source.end_date,
    source.type,
    source.total,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM source
LEFT JOIN existing_data e 
  ON source.id = e.id