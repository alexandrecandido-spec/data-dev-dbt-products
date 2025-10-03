select 
    msi.store_id,
    msi.state,
    msi.country,
    msi.currency,
    msi.current_segment,
    msi.first_payment,
    msi.churned_at,
    gp.grupo plan_name,
    msi.created_at merchant_created_at,
    1 as has_saved_searches_available,
    min(date(mt.created)) as saved_searches_available_at,
    max(mt.sys_audit_updated_on) as sys_audit_updated_on
from {{ source('int_moltres', 'mwp_tags') }}  mt
inner join {{ ref('moltres__mwp_store_info') }} msi on msi.store_id = mt.related_id
left join {{ ref('operations_grouping_plans') }} gp on gp.plan = msi.plan
where mt.type = 'store'
AND 
(tag = 'new-admin-orders-api-saved-searches')
group by 
    store_id,
    state,
    country,
    currency,
    current_segment,
    first_payment,
    churned_at,
    plan_name,
    merchant_created_at,
    has_saved_searches_available