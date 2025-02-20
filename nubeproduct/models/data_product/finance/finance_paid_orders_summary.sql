{{
    config(
        materialized='incremental',
        unique_key=['store_id','completed_at','storefront'],
        incremental_strategy='merge',
        on_schema_change='fail',
        tags=["daily-morning"]
    )
}}

WITH
blocked_stores AS (
    SELECT
        DISTINCT related_id
    FROM {{ source('dp_moltres', 'mwp_tags') }} as tg
    WHERE tg.type = 'store'
        AND (tg.tag = 'sre-block-store-429'
            OR tg.tag = 'sre-block-store-404')
),
orders_summary as (
    SELECT
        orders.store_id,
        orders.order_date_store_id,
        store_info.country,
        orders.storefront,
        CASE
            WHEN store_info.country = 'AR' THEN 'ARS'
            WHEN store_info.country = 'BR' THEN 'BRL'
            WHEN store_info.country = 'MX' THEN 'MXN'
            WHEN store_info.country = 'CO' THEN 'COP'
            WHEN store_info.country = 'CL' THEN 'CLP'
            ELSE store_info.currency
        END AS currency,
        DATE(orders.completed_at) AS completed_at,
        DATE(orders.created_at) AS created_at,
        SUM(orders.total_in_usd) AS gmv,
        COUNT(orders.order_id) AS orders
    FROM {{ ref('stg_finance__orders_mwp_orders') }} orders 
    INNER JOIN {{ ref('stg_moltres__mwp_store_info') }} store_info on orders.store_id = store_info.store_id
    WHERE 
        orders.cancelled_at IS NULL
        AND completed_at IS NOT NULL
        {% if is_incremental() %}

        -- this filter will only be applied on an incremental run
        -- (uses >= to include records whose timestamp occurred since the last run of this model)
        -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
        AND (orders.completed_at >= (
            SELECT MAX(sys_audit_updated_on) FROM dp_finance.finance_paid_orders_summary
            )
        OR orders.order_date_store_id IN (
            SELECT DISTINCT order_date_store_id FROM {{ ref('stg_finance__orders_mwp_orders') }}
            WHERE orders.cancelled_at >= (SELECT MAX(sys_audit_updated_on) FROM dp_finance.finance_paid_orders_summary)
            ))

        {% endif %}
        AND orders.payment_status = 'paid'
        AND orders.status <> 'cancelled'
        AND orders.store_id NOT IN (
            SELECT
                DISTINCT related_id
            FROM {{ source('dp_moltres', 'mwp_tags') }} as tg
            WHERE tg.type = 'store'
                AND (tg.tag = 'sre-block-store-429'
                    OR tg.tag = 'sre-block-store-404')
                    )
    GROUP BY 
        orders.store_id,
        orders.order_date_store_id,
        DATE(orders.created_at),
        DATE(completed_at),
        orders.storefront,
        store_info.country,
        store_info.currency
),
final_group AS (
    SELECT
        orders_summary.store_id,
        orders_summary.country,
        orders_summary.storefront,
        orders_summary.completed_at,
        orders_summary.gmv,
        SUM(orders_summary.gmv / currency_conversion.exchange_rate) AS gmv_local,
        orders_summary.currency,
        orders_summary.orders
        FROM orders_summary
    LEFT JOIN {{ source('dp_finances', 'dp_currency_conversion') }} currency_conversion 
        ON orders_summary.created_at = currency_conversion.updated_at 
            AND  orders_summary.currency = currency_conversion.isocode
    GROUP BY
        orders_summary.store_id,
        orders_summary.country,
        orders_summary.storefront,
        orders_summary.created_at,
        orders_summary.completed_at,
        orders_summary.gmv,
        orders_summary.currency,
        orders_summary.orders
), 
existing_data AS (
    {{ get_existing_data(this, ['store_id', 'storefront', 'completed_at', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
    final_group.store_id,
    final_group.country,
    final_group.storefront,
    final_group.completed_at,
    final_group.gmv AS gmv_usd,
    final_group.gmv_local as gmv_local_currency,
    final_group.currency as local_currency,
    final_group.orders,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM final_group 
LEFT JOIN existing_data e ON final_group.store_id = e.store_id and final_group.storefront = e.storefront and final_group.completed_at = e.completed_at
