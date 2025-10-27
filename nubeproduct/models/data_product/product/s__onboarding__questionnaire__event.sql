{{
    config(
        materialized='incremental',
        unique_key= ['store_id', 'group_code', 'description'],
        on_schema_change='fail', 
        tags=['daily-10am'] 
    )
}}

WITH questionnaire AS (
    SELECT * 
    FROM {{ ref('_int__product__onboarding_store_preferences') }}

    {% if is_incremental() %}
    WHERE 
        sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }})
    {% endif %}

),

existing_data AS (
    {{ get_existing_data(this, ['store_id', 'group_code', 'description', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT
    q.store_id,
    q.group_code,
    q.description,
    q.free_text,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM questionnaire q
LEFT JOIN existing_data e
    ON q.store_id = e.store_id

