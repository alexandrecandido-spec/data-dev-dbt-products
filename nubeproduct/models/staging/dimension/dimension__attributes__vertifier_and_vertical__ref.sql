{{
    config(
        materialized='incremental',
        unique_key=['store_id'],
        on_schema_change='fail',
        tags=['dimensions','daily-4am']
    )
}}

WITH latest_vertifier AS (
    SELECT 
    store_id, 
    CASE WHEN vertifier IS NULL THEN 'Not Informed' WHEN vertifier IN ('','unknown') THEN 'Not Informed' ELSE vertifier END AS vertifier
    FROM
    (
        SELECT 
        store_id, 
        vertifier, 
        ROW_NUMBER() OVER(PARTITION BY store_id ORDER BY created_at DESC) AS rnk
        FROM   {{ ref('antifraud_service__vertifier_store_inferences') }} 
        ) 
    WHERE rnk = 1
),
source AS (
    SELECT  
    s.store_id, 
    s.type, 
    s.sys_audit_updated_on
    FROM {{ source('stg_moltres','mwp_store_settings') }} s
    WHERE 
    {% if is_incremental() %}
    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    s.sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} )
    {% else %}
        1 = 1 -- this will always be true if not incremental
    {% endif %}
),
existing_data AS (
    {{ get_existing_data(this, ['store_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
s.store_id, 
CASE WHEN s.type IS NULL THEN v.vertifier ELSE s.type END AS vertical_name, 
COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
current_timestamp AS sys_audit_updated_on,
'data-dev-dbt-products' AS sys_audit_updated_by
FROM source s
LEFT JOIN latest_vertifier v ON v.store_id = s.store_id
LEFT JOIN existing_data e ON s.store_id = e.store_id
