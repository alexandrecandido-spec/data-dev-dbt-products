-- Owner: Guille De Felice

select 
    si.store_id,
    si.plan as plan_id,
    si.country,
    pc.monthly,
    pc.context,
    p.nice_name,
    p.transaction_fee,
    p.transaction_fee_type,
    domain as store_name,
    churned_at, 
    first_payment
from
    {{ ref('moltres__mwp_store_info') }} si
    inner join {{ ref('midmarket_success_stores') }} s
        on si.store_id = s.store_id
    left join {{ source('int_moltres', 'mwp_plans_countries') }} pc
        on si.plan = pc.id
    left join {{ source('int_moltres', 'mwp_plans') }} p
        on pc.plan = p.id