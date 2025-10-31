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
    case when os.saved_search_id is not null then 1 else 0 end as saved_searches_user,
    min(date(coalesce(mt.created,'2025-10-29'))) as saved_searches_available_at,
    min(date(saved_search_created_at)) as saved_searches_first_use,
    max(date(saved_search_created_at)) as saved_searches_last_use,
    count(case when saved_search_default = 0 then saved_search_id end) as saved_searches_count,
    -- Combined audit field for all sources in this model
    GREATEST(
        COALESCE(max(mt.sys_audit_updated_on), '1900-01-01'),
        COALESCE(max(msi.sys_audit_updated_on), '1900-01-01'),
        COALESCE(max(gp.sys_audit_updated_on), '1900-01-01'),
        COALESCE(max(os.max_sys_audit_updated_on), '1900-01-01')
    ) as max_sys_audit_updated_on
from {{ ref('moltres__mwp_store_info') }} msi
left join (select related_id,created, sys_audit_updated_on from {{ source('int_moltres', 'mwp_tags') }} where type = 'store' AND (tag = 'new-admin-orders-api-saved-searches')) mt on msi.store_id = mt.related_id
left join {{ ref('operations_grouping_plans') }} gp on gp.plan = msi.plan
left join {{ ref('_int_product__orders_saved_searches') }} os on os.store_id = msi.store_id

group by 
    msi.store_id,
    msi.state,
    msi.country,
    msi.currency,
    msi.current_segment,
    msi.first_payment,
    msi.churned_at,
    gp.grupo,
    msi.created_at,
    has_saved_searches_available,
    saved_searches_user