{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['order_id'],
        partition_by='year_month_day_code',
        on_schema_change='fail',
        tags=["daily-2am"]
    )
}}

WITH existing_data AS (
    {{ get_existing_data(this, ['order_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT
    source.order_id,
    source.utm_source,
    source.utm_medium,
    source.http_referrer,
    source.source,
    source.source_details,
    source.source_name,
    source.source_type,
    source.completed_at,
    source.year_month_day_code,

    -- Campos de auditoria
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by

FROM {{ ref('_int_orders_social_order_source') }} source
LEFT JOIN existing_data e ON source.order_id = e.order_id

WHERE
    {% if not is_incremental() %}
        source.completed_at >= '2018-01-01'
    {% endif %}
    {% if is_incremental() %} 
        source.completed_at >= (
            SELECT MAX(DATE(sys_audit_updated_on)) FROM {{ this }}
        )
    {% endif %}
