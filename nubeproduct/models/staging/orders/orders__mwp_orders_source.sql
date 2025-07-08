{{
    config(
        materialized='incremental',
        unique_key='order_id',
        partition_by='year_month_code',
        on_schema_change='fail',
        tags=["operations", "daily-8am-8pm"]
    )
}}

WITH source AS (
    SELECT 
        order_id,
        source,
        source_details,
        utm_source,
        utm_medium,
        http_referrer,
        created_at,
        year_month_code
    FROM {{ source('stg_orders', 'mwp_orders_source') }}
    WHERE --created_at >= '2017-12-31'
    year_month_code >= 201801
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
    source.year_month_code,
    -- Auditoria
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by

FROM source
LEFT JOIN existing_data e ON source.order_id = e.order_id
