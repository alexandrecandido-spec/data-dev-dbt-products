select 
store_id,
1 edit_orders_user,
max(sys_audit_updated_on) sys_audit_updated_on,
min(date(happened_at)) edit_first_use,
max(date(happened_at)) edit_last_use,
count(distinct id) edit_count
FROM {{ source('int_orders', 'orders_edit_history') }} 
group by store_id,edit_orders_user