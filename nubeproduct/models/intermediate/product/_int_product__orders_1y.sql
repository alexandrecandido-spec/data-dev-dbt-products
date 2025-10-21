SELECT
o.id order_id,
o.total,
o.gateway_method,
o.gateway,
apps.handle as gateway_handle,
o.status,
o.total_in_usd,
date(o.completed_at) order_completed_at,
date(o.cancelled_at) as order_cancelled_at,
payment_status,
gp.grupo as plan,
o.cancel_reason,
o.store_id,
i.domain,
i.country,
i.state,
i.current_segment,
o.year_month_day_code,
GREATEST(
    o.sys_audit_updated_on,
    i.sys_audit_updated_on,
    gp.sys_audit_updated_on,
    apps.sys_audit_updated_on
) as max_sys_audit_updated_on
from {{ ref('orders__mwp_orders') }}  o
left join {{ ref('moltres__mwp_store_info') }} i on i.store_id = o.store_id
left join {{ ref('operations_grouping_plans') }} gp on gp.plan = i.plan
left join {{ ref('moltres__mwp_apps') }} apps on concat('app_',apps.id) = o.gateway
where
TO_DATE(cast(year_month_day_code as string), 'yyyyMMdd') >= DATE_SUB(current_date(), 365)
and completed_at is not null 