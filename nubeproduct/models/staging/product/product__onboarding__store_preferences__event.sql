{{
    config(
        materialized='incremental',
        unique_key= 'id',
        on_schema_change='fail', 
        tags=['product', 'daily-9am']
    )
}}

WITH store_preferences AS ( 
    SELECT
        CAST(id AS string) AS id,
        CAST(created_at AS timestamp) AS created_at,
        CAST(domain_mapping_id AS string) AS domain_mapping_id,
        CAST(store_id AS string) AS store_id,
        LOWER(TRIM(REGEXP_REPLACE(TRANSLATE(sp.free_text, 'áàâãäéèêëíìîïóòôõöúùûüç', 'aaaaaeeeeiiiiooooouuuuc'),'[^a-z ]',''))) AS free_text,
    FROM {{ source('stg_onboarding', 'store_preferences') }} 

    {% if is_incremental() %}
        WHERE sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} )
    {% endif %}
),

existing_data AS (
    {{ get_existing_data(this, ['id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
    sp.*,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM store_preferences AS sp
LEFT JOIN existing_data e ON sp.id = e.id