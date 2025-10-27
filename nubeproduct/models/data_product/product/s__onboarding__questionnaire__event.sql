{{
    config(
        materialized='incremental',
        unique_key= ['store_id', 'group_code', 'description'],
        on_schema_change='fail', 
        tags=['daily-10am'] 
    )
}}

WITH questionnaire AS (
    SELECT
        sp.store_id AS store_id,
        sp.created_at AS created_at,
        CAST(REPLACE(dm.group_code,  '_' || split_part(dm.group_code, '_', -1),'') AS STRING) AS group_code,
        CAST(dt.description AS STRING) AS description,
        sp.free_text AS free_text    
    FROM {{ ref('product__onboarding__store_preferences__event') }} AS sp
    LEFT JOIN {{ source('dp_onboarding', 'domain_mappings') }} AS dm
        ON dm.id = sp.domain_mapping_id
    LEFT JOIN {{ source('dp_onboarding', 'domain_types') }} AS dt 
        ON dm.type_code = dt.code

    {% if is_incremental() %}
    WHERE 
        sp.sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }})
    {% endif %}

),

existing_data AS (
    {{ get_existing_data(this, ['store_id', 'group_code', 'description', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT
    q.store_id,
    q.created_at,
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
    AND q.group_code = e.group_code
    AND q.description = e.description


