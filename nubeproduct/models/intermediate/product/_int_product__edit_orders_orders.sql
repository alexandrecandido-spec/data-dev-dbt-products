select 
    id,
    store_id,
    cast(completed_at as date) as order_completed_at,
    payment_status,
    status,
    total_in_usd as gmv_usd,
    year_month_day_code order_year_month_day_code,
    sys_audit_updated_on
    FROM   {{ ref('orders__mwp_orders') }} 
    where storefront in ('store', 'permalink', 'pos', 'form', 'mobile', 'api') 
    and date(completed_at) >=  DATE_ADD(MONTH, -12, now())
    and completed_at is not null
    AND id IS NOT NULL 