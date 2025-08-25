    select distinct
        date_trunc('month', datemonth) as registered_month
    from {{ ref('company_metrics_gmv_and_segments') }} 