-- _int__product__shipping__international_orders

WITH blocked as (
    SELECT
    DISTINCT CAST(related_id as BIGINT) as store_id
    FROM {{ source('int_moltres', 'mwp_tags') }}
    WHERE type = 'store'
    AND (tag = 'sre-block-store-429' OR tag = 'sre-block-store-404')
)

SELECT
    o.id as order_id,
    c.code as shipping_country_code,
    c.name_en as shipping_country_name,
    CASE
        WHEN c.code <> sc.country AND o.shipping_country IS NOT NULL AND sc.country IS NOT NULL THEN TRUE
        ELSE FALSE
    END AS is_international_shipping

FROM {{ source('int_stg_orders', 'mwp_orders') }} o -- uso la tabla cruda porque las demás no tienen los campos que necesito (ej. shipping_country)

JOIN {{ ref('s__lifecycle__store_status__ref') }} ss
    ON o.store_id = ss.store_id

JOIN {{ ref('s__attributes__store_core__ref') }} sc
    ON o.store_id = sc.store_id

LEFT JOIN {{ source('int_moltres', 'mwp_countries') }} c
    ON o.shipping_country = c.id

WHERE 1=1
    AND o.store_id NOT IN (SELECT store_id FROM blocked)
    AND o.storefront IN ('mobile', 'store', 'form', 'social')
    AND DATE(o.completed_at) > DATE(DATE_ADD('month', -13, current_date))
    AND o.payment_status = 'paid'
    AND o.status <> 'cancelled'
    AND o.order_id IS NOT NULL
    AND o.total_in_usd <= 10000 AND o.total_in_usd >= -10000
    AND ss.state <> 4
