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
        SUM(orders.total_in_usd) AS gmv,
        COUNT(orders.order_id) AS orders
    FROM {{ ref('stg_finance__orders_mwp_orders') }} orders 
    INNER JOIN {{ ref('stg_moltres__mwp_store_info') }} store_info on orders.store_id = store_info.store_id
    WHERE 
        {% if is_incremental() %}

        -- this filter will only be applied on an incremental run
        -- (uses >= to include records whose timestamp occurred since the last run of this model)
        -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
        orders.cancelled_at IS NULL 
        AND (orders.completed_at >= (
            date_sub(current_date(), 1) 
            )
        OR orders.order_date_store_id IN (
            SELECT DISTINCT order_date_store_id FROM {{ ref('stg_finance__orders_mwp_orders') }}
            WHERE orders.cancelled_at >= date_sub(current_date(), 1) 
            
            ))
        AND

        {% endif %}
        orders.payment_status = 'paid'
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
        ON orders_summary.completed_at = currency_conversion.updated_at 
            AND  orders_summary.currency = currency_conversion.isocode
    GROUP BY
        orders_summary.store_id,
        orders_summary.country,
        orders_summary.storefront,
        orders_summary.completed_at,
        orders_summary.gmv,
        orders_summary.currency,
        orders_summary.orders
)

SELECT 
    *,
    {{add_audit_columns()}}
FROM final_group