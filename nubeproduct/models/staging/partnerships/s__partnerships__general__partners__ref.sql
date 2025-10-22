{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['partner_id'],
    on_schema_change='fail',
    tags=['daily-6am','partnerships']
) }}

WITH existing_data AS (
    {{ get_existing_data(this, ['id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
    CAST(s.id as INT) as partner_id,
    CAST(s.code as STRING) as partner_code,
    CAST(s.name as STRING) as partner_name,
    CAST(s.country as INT) as partner_country_id,
    CAST(s.created_at as TIMESTAMP) as partner_created_at,
    CAST(s.email as STRING) as partner_email,
    CAST(s.phone_number as STRING) as partner_phone_number,

    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ source('int_ecosystem', 'mwp_partners') }} AS s
LEFT JOIN existing_data e
    ON s.id = e.id
    {% if is_incremental() %}
        AND s.sys_audit_updated_on >= (
            SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01')
            FROM {{ this }}
        )
    {% endif %}
