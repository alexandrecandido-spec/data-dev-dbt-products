with 
blocked_stores AS (
    SELECT
        related_id
    FROM {{ source('int_moltres', 'mwp_tags') }} as tg
    WHERE tg.type = 'store'
        AND (tg.tag = 'sre-block-store-429'
            OR tg.tag = 'sre-block-store-404')
),

paid_orders as (
    select * from {{ ref('company_metrics_paid_orders') }}
    WHERE store_id NOT IN (SELECT related_id FROM blocked_stores)
),

paid_orders_window as (
    select
        o1.store_id,
        o1.completed_at,
        count(o2.id) as sales_90d
    from paid_orders o1
    inner join paid_orders o2
        on o1.store_id = o2.store_id
        and o2.completed_at between dateadd(day, -90, o1.completed_at) and o1.completed_at
    where o1.year_month_day_code >= 20250101
      and o2.year_month_day_code >= 20250101
    group by o1.store_id, o1.completed_at
)

select * 
from paid_orders_window

