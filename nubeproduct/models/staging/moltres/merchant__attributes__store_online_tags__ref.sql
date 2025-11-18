{{
    config(
        materialized='incremental',
        incremental_strategy = 'merge',
        unique_key='store_id',
        on_schema_change='fail',
        tags=["merchant","daily-8am-8pm"],
        post_hook=[
            "DELETE FROM {{ this }}
                    WHERE store_id NOT IN (
                        SELECT 
                            distinct related_id
                        FROM 
                            {{ source('stg_moltres', 'mwp_tags') }}
                        WHERE 
                            type = 'store'
                            AND tag IN ('online-metrics-enabled', 'lightspeed')
                            )"
            ]
    )
}}


-- gets stores that have online-metrics-enabled or lightspeed tags
WITH source_data AS (
    SELECT 
        related_id AS store_id,
        MAX(case when tag = 'online-metrics-enabled' then sys_audit_updated_on else null end) AS online_metrics_enabled_last_updated_at,
        MAX(case when tag = 'lightspeed' then sys_audit_updated_on else null end) AS lightspeed_last_updated_at
    FROM 
        {{ source('stg_moltres', 'mwp_tags') }}
    WHERE 
        type = 'store'
        AND tag IN ('online-metrics-enabled', 'lightspeed')
    {% if is_incremental() %}
    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    AND sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} )
    {% endif %}
    GROUP BY 
        related_id
),
existing_data AS (
    {{ get_existing_data(this, ['store_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
    sd.store_id,
    sd.online_metrics_enabled_last_updated_at,
    sd.lightspeed_last_updated_at,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM source_data sd
LEFT JOIN existing_data e ON sd.store_id = e.store_id