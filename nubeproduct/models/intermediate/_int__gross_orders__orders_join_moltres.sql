WITH apps AS (
    SELECT 
        id as app_id,
        handle
    FROM {{ source('intermediate', 'mwp_apps') }}
),
store_settings AS (
    SELECT
        id,
        store_id, 
        type,
        COALESCE(type, 'undefined') as vertical
    FROM {{ source('intermediate', 'mwp_store_settings') }}
),
orders AS (
    SELECT *
    FROM {{ ref('stg_orders__mwp_orders') }}
    WHERE storefront in ('mobile', 'store')
),
store_info AS (
    SELECT *
    FROM {{ ref('stg_moltres__mwp_store_info') }}
    WHERE country in ('AR','BR')
)

SELECT
    orders.order_id,
    orders.created_at,
    orders.started_checkout_at,
    orders.completed_contact_at,
    orders.completed_at,
    orders.contact_email,
    orders.total_in_usd,
    orders.storefront,
    orders.is_paid_order,
    orders.device,
    apps.handle,
    store_info.country,
    store_settings.type,
    store_info.current_segment,
    CASE  
        WHEN store_infocurrent_segment = 'top-seller'         THEN 'A: Top Seller'
        WHEN store_infocurrent_segment = 'large-seller'       THEN 'B: Large Seller'
        WHEN store_infocurrent_segment = 'medium-seller'      THEN 'C: Medium Seller'
        WHEN store_infocurrent_segment = 'small-seller'       THEN 'D: Small Seller'
        WHEN store_infocurrent_segment = 'tiny-seller'        THEN 'E: Tiny Seller'
        WHEN store_infocurrent_segment = 'struggling-seller'  THEN 'F: Struggling Seller'
        WHEN store_infocurrent_segment = 'no-seller'          THEN 'G: No Seller'
        ELSE 'H: Undefined'
    END AS store_current_segment
FROM orders
LEFT JOIN apps ON orders.gateway = CONCAT('app_', CAST(apps.id AS varchar(5)))
INNER JOIN store_info ON order.store_id = store_info.store_id
LEFT JOIN store_settings ON order.store_id = store_settings.store_id
WHERE orders.created >= DATE_ADD(DAY, -31, CURRENT_DATE)