{{ 
    config(
        materialized = 'incremental',
        incremental_strategy = 'merge',
        unique_key = ['group_id'],
        on_schema_change = 'fail',
        tags = ['daily-6am']
) }}    

WITH existing_data AS (
    {{ get_existing_data(this, ['group_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT
    G.group_id,
    G.group_url,
    G.group_name,
    G.group_description,
    G.is_default,
    G.is_deleted,
    G.group_created_at,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ ref('_int_cx__zendesk_groups__info') }} AS G
LEFT JOIN existing_data AS e
    ON G.group_id = e.group_id
    {% if is_incremental() %}
WHERE    
      G.group_updated_at > 
        (
            SELECT COALESCE(MAX(sys_audit_updated_on), DATE '1900-01-01')
            FROM {{ this }}
        )
    {% endif %}