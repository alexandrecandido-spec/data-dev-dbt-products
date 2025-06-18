{{
    config(
        materialized='incremental',
        unique_key='order_id',
        partition_by='created_at',
        on_schema_change='fail',
        tags=["operations", "daily-8am-8pm"]
    )
}}

WITH source AS (
    SELECT 
        order_id,
        LOWER(source) AS source,
        LOWER(source_details) AS source_details,
        LOWER(utm_source) AS utm_source,
        LOWER(utm_medium) AS utm_medium,
        LOWER(http_referrer) AS http_referrer,
        created_at
    FROM {{ source('stg_orders', 'mwp_orders_source') }}
    WHERE --created_at >= '2017-12-31'
    created_at between '2017-12-31' and '2018-02-28'
    AND created_at IS NOT NULL
    AND order_id IS NOT NULL

    {% if is_incremental() %}
        AND created_at >= (SELECT MAX(created_at) FROM {{ this }})
    {% endif %}
),

existing_data AS (
    {{ get_existing_data(this, ['order_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT
    source.order_id,
    source.source,
    source.source_details,
    source.utm_source,
    source.utm_medium,
    source.http_referrer,
    source.created_at,
    
    -- Auditoria
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by

FROM source
LEFT JOIN existing_data e ON source.order_id = e.order_id
