-- Owner: Guille De Felice

with gmv as (
    select 
        gas.store_id,
        round(gmv_local_currency_on_platform_90d/3, 2) as avg_gmv_lc_90d
    from 
        {{ ref('company_metrics_gmv_and_segments') }} gas
        inner join {{ ref('_int_midmarket_wbr_mbr__weekly_franchise_group') }} fg
            on gas.store_id = fg.store_id
    where 
        datemonth = date_trunc('month', current_date) - interval '1' day
),

-- Rankeo por GMV dentro de cada franchise_group
stores_ranked as (
    select 
        fg.store_id,
        fg.franchise_group,
        coalesce(g.avg_gmv_lc_90d, 0) as avg_gmv_lc_90d,
        fg.in_portfolio,
        row_number() over (
            partition by fg.franchise_group
            order by coalesce(g.avg_gmv_lc_90d, 0) desc, fg.store_id asc
        ) as row_num
    from {{ ref('_int_midmarket_wbr_mbr__weekly_franchise_group') }} fg
    left join gmv g
        on fg.store_id = g.store_id
),

-- Señales para decidir el "segundo main" cuando la top no está en portfolio
annotated as (
    select
        *,
        first_value(in_portfolio) over (
            partition by franchise_group
            order by row_num
        ) as top_in_portfolio,
        min(case when in_portfolio then row_num end) over (
            partition by franchise_group
        ) as first_in_portfolio_row
    from stores_ranked
)

select
    store_id,
    case
        when row_num = 1 then true
        when top_in_portfolio = false and row_num = first_in_portfolio_row then true
        else false
    end as main
from annotated