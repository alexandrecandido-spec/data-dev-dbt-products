-- Owner: Guille De Felice

with franchise_and_interaction as (
    select 
        sid.store_id,
        lower(trim(t.tag)) as franchise_group,
        lri.last_relevant_interaction,
        sid.in_portfolio,
            ROW_NUMBER() OVER (
            PARTITION BY t.related_id
            ORDER BY t.created DESC
        ) AS row_num
    from  {{ source('int_moltres', 'mwp_tags') }} t
        inner join {{ ref('midmarket_success_stores') }} sid
            on t.related_id = sid.store_id 
            and (sid.in_portfolio = true
                or sid.store_id in (select store_id from {{ ref('_int_midmarket_wbr_mbr__last_week_stores') }}))
        left join {{ ref('_int_midmarket_wbr_mbr__last_relevant_interaction') }} lri
            on sid.store_id = lri.store_id
    where 
        lower(trim(tag)) LIKE 'group-%'
),
max_interaction as (
    select
        franchise_group,
        max(last_relevant_interaction) as last_group_interaction
    from 
        franchise_and_interaction fai
    where
        row_num = 1
    group by 1
)
select 
    store_id,
    in_portfolio,
    fai.franchise_group,
    last_group_interaction
from 
    franchise_and_interaction fai
    inner join max_interaction mi 
        on fai.franchise_group = mi.franchise_group
where 
    fai.row_num = 1