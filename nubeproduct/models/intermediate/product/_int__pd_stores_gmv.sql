    select 
        DATE_TRUNC('MONTH', datemonth) as registered_month,
        store_id,
        country,
        sum(orders_monthly) as total_orders,
        sum(gmv_local_currency_monthly) as gmv_local_currency
    from {{ ref('company_metrics_gmv_and_segments') }}
    where DATE_TRUNC('MONTH', datemonth) between DATE_TRUNC('MONTH', CURRENT_DATE) - INTERVAL '3' MONTH 
        and DATE_TRUNC('MONTH', CURRENT_DATE) - INTERVAL '1' MONTH 
    group by 1,2,3,4