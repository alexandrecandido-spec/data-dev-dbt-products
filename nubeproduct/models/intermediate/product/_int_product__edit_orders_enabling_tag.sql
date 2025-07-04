select 
related_id,
1 as has_edit_orders_disponible,
min(date(created)) as fecha_edit_orders_disponible

from {{ source('int_moltres', 'mwp_tags') }}  mt
where mt.type = 'store'
AND 
(tag = 'new-admin-order-edit'
OR tag = 'new-admin-order-edit-new-features')
group by 1,2