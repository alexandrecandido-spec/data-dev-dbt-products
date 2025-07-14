select 
related_id,
1 as has_edit_orders_available,
    min(date(created)) as edit_orders_available_at,
max(sys_audit_updated_on) as sys_audit_updated_on
from {{ source('int_moltres', 'mwp_tags') }}  mt
where mt.type = 'store'
AND 
(tag = 'new-admin-order-edit'
OR tag = 'new-admin-order-edit-new-features')
group by 
related_id,
has_edit_orders_available