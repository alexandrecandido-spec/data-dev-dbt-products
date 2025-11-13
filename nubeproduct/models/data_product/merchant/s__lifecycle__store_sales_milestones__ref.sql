{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['store_id'],
        on_schema_change='fail',
        tags=['daily-8am-8pm']
    )
}}

WITH 
-- Identify stores that need recalculation (stores with any updated orders)
{% if is_incremental() %}
stores_to_update AS (
    SELECT DISTINCT o.store_id
    FROM {{ ref('company_metrics_paid_orders') }} o
    WHERE o.sys_audit_updated_on > ( SELECT COALESCE(MAX(sys_audit_updated_on), DATE '1900-01-01') FROM {{ this }} )
),
{% endif %}

sale_ranks AS (
    SELECT
        o.store_id,
        o.gateway,
        o.shipping_method,
        o.payment,
        o.shipping,
        o.storefront,
        o.total,
        o.total_in_usd,
        CASE    
            WHEN i.country_code = 'AR' THEN TO_DATE(CONVERT_TIMEZONE( 'UTC', 'America/Argentina/Buenos_Aires',  o.completed_at),'YYYY-MM-DD')
            WHEN i.country_code = 'MX' THEN TO_DATE(CONVERT_TIMEZONE( 'UTC', 'America/Mexico_City',  o.completed_at),'YYYY-MM-DD')
            WHEN i.country_code = 'BR' THEN TO_DATE(CONVERT_TIMEZONE( 'UTC', 'America/Sao_Paulo',  o.completed_at),'YYYY-MM-DD')
            WHEN i.country_code = 'CO' THEN TO_DATE(CONVERT_TIMEZONE( 'UTC', 'America/Bogota',  o.completed_at),'YYYY-MM-DD')
            ELSE TO_DATE(o.completed_at,'YYYY-MM-DD') 
        END as completed_at,
        row_number() over(partition by o.store_id order by o.completed_at asc) as index_asc,
        row_number() over(partition by o.store_id order by o.completed_at desc) as index_desc
    FROM {{ ref('company_metrics_paid_orders') }} o
    LEFT JOIN {{ ref('s__attributes__store_core__ref') }} i ON o.store_id = i.store_id
    WHERE 
    {% if not is_incremental() %}
        o.sys_audit_updated_on >= DATE '1900-01-01'
    {% endif %}
    {% if is_incremental() %}
        o.store_id IN (SELECT store_id FROM stores_to_update)
    {% endif %}
    ),

first_and_last_sale AS (
SELECT
    sr.store_id,
    MAX(case when sr.index_asc = 1 then gateway else null end) as payment_gateway_first_sale,
    MAX(case when sr.index_asc = 1 then shipping_method else null end) as shipping_gateway_first_sale,
    MAX(case when sr.index_asc = 1 then payment else null end) as payment_method_first_sale,
    MAX(case when sr.index_asc = 1 then shipping else null end) as shipping_method_first_sale,
    MAX(case when sr.index_asc = 1 then storefront else null end) as storefront_first_sale,
    MAX(case when sr.index_asc = 1 then total else null end) as total_first_sale,
    MAX(case when sr.index_asc = 1 then total_in_usd else null end) as total_in_usd_first_sale,
    MAX(case when sr.index_asc = 1 then completed_at else null end) as first_sale,
    MAX(case when sr.index_desc = 1 then gateway else null end) as payment_gateway_last_sale,
    MAX(case when sr.index_desc = 1 then shipping_method else null end) as shipping_gateway_last_sale,
    MAX(case when sr.index_desc = 1 then payment else null end) as payment_method_last_sale,
    MAX(case when sr.index_desc = 1 then shipping else null end) as shipping_method_last_sale,
    MAX(case when sr.index_desc = 1 then storefront else null end) as storefront_last_sale,
    MAX(case when sr.index_desc = 1 then total else null end) as total_last_sale,
    MAX(case when sr.index_desc = 1 then total_in_usd else null end) as total_in_usd_last_sale,
    MAX(case when sr.index_desc = 1 then completed_at else null end) as last_sale
FROM sale_ranks sr
GROUP BY sr.store_id),

existing_data AS (
    {{ get_existing_data(this, ['store_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT
    fas.store_id,
    fas.payment_gateway_first_sale,
    fas.shipping_gateway_first_sale,
    fas.payment_method_first_sale,
    fas.shipping_method_first_sale,
    fas.storefront_first_sale,
    fas.total_first_sale,
    fas.total_in_usd_first_sale,
    fas.first_sale,
    fas.payment_gateway_last_sale,
    fas.shipping_gateway_last_sale,
    fas.payment_method_last_sale,
    fas.shipping_method_last_sale,
    fas.storefront_last_sale,
    fas.total_last_sale,
    fas.total_in_usd_last_sale,
    fas.last_sale,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM first_and_last_sale fas
LEFT JOIN existing_data e ON fas.store_id = e.store_id