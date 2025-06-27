select 
    id as order_id,
    store_id,
    cast(completed_at as date) as fecha_completed_at,
    payment_status,
    status,
    total_in_usd as gmv_usd,
    discount coupon_discount,
    discount_gateway gateway_discount,
    promotional_discount_id promo_discount,
    shipping_cost_owner,
    shipping_cost 
    FROM   {{ ref('orders__mwp_orders') }} 
    where storefront in ('store', 'permalink', 'pos', 'form', 'mobile', 'api') 
    and date(completed_at) >=  DATE_ADD('month', -7, now())
    and completed_at is not null
    AND order_id IS NOT NULL 