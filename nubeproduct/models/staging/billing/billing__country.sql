{{
  config(
    materialized='incremental',
    unique_key='country_id',
    on_schema_change='fail',
    tags=['finance', 'daily-7am']
  )
}}

WITH source_data AS (
    SELECT
        id AS country_id,
        code AS country_code,
        sys_audit_created_on AS source_sys_audit_created_on,
        sys_audit_created_by AS source_sys_audit_created_by,
        -- updatedat column not available in this source table
        CAST(date_format(sys_audit_created_on, 'yyyyMMdd') AS INT) AS year_month_day_code
    FROM
        {{ source('stg_billing', 'country') }}

    -- No updatedat column available for incremental logic
),

existing_data AS (
    {{ get_existing_data(this, ['country_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT
    s.country_id,
    s.country_code,
    s.year_month_day_code,
    -- s.updated_at, -- Column not available
    COALESCE(e.sys_audit_created_on, s.source_sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, s.source_sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM
    source_data s
LEFT JOIN
    existing_data e ON s.country_id = e.country_id