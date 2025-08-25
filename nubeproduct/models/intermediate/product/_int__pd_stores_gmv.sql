    select
        datemonth as registered_month
        ,store_id
        ,gmv_local_currency_monthly as avg_gmv_lc_last_3months
        ,gmv_usd_monthly
        ,orders_monthly as avg_orders_last_3months
    from {{ ref('company_metrics_gmv_and_segments') }} 