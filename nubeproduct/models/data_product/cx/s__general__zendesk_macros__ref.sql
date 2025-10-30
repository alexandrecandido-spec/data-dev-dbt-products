{{ 
    config(
        materialized = 'incremental',
        incremental_strategy = 'merge',
        unique_key = ['macro_id'],
        on_schema_change = 'fail',
        tags = ['cx','daily-6am']
) }}    

WITH existing_data AS (
    {{ get_existing_data(this, ['macro_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT
    M.macro_id,
    M.macro_url,
    M.macro_title,
    M.macro_description,
    M.is_active,
    M.macro_created_at,
    M.comment_mode_is_public,
    M.comment_value_html,
    M.current_tags,
    M.status,
    M.side_conversation_flg,
    M.restriction_type,
    M.restriction_id,
    M.restriction_ids,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,    
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ ref('_int_cx__zendesk_macros__info') }} AS M
LEFT JOIN existing_data AS e
    ON M.macro_id = e.macro_id
    {% if is_incremental() %}
WHERE    
      M.macro_updated_at > 
        (
            SELECT COALESCE(MAX(sys_audit_updated_on), DATE '1900-01-01')
            FROM {{ this }}     
        )
    {% endif %}