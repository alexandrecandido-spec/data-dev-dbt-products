-- Owner: Guille De Felice

with gmv as (
    select 
        gas.store_id,
        round(gmv_local_currency_on_platform_90d/3, 2) as avg_gmv_lc_90d
    from 
        {{ ref('company_metrics_gmv_and_segments') }} gas
        inner join {{ ref('midmarket_success_stores') }} ss
            on gas.store_id = ss.store_id
    where 
        datemonth = date_trunc('month', current_date) - interval '1' day
),
stores_and_gmv as (
    select 
        ss.store_id,
        franchise_group,
        avg_gmv_lc_90d,
        ROW_NUMBER() OVER (
            PARTITION BY franchise_group 
            ORDER BY avg_gmv_lc_90d DESC, ss.store_id ASC
        ) AS row_num
    FROM {{ ref('midmarket_success_stores') }} ss
        left join {{ ref('_int_midmarket_wbr_mbr__franchise_group') }} fg
            on ss.store_id = fg.store_id
        left join gmv
            on ss.store_id = gmv.store_id
    WHERE 
        ss.in_portfolio = true
)
SELECT 
    store_id,
    CASE 
        WHEN franchise_group IS NULL THEN TRUE
        WHEN row_num = 1 THEN TRUE
        ELSE FALSE
    END AS main
from stores_and_gmv