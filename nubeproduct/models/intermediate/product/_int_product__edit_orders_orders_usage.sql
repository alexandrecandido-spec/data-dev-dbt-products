select 
    o.id,
    o.fecha_completed_at,
    o.payment_status,
    o.status,
    o.gmv_usd,
    o.year_month_day_code,
    o.store_id,
    case when h.id is not null then 1 else 0 end as was_order_edited,
    max(o.sys_audit_updated_on) as sys_audit_updated_on,
    min(date(happened_at)) order_first_edited_at,
    max(date(happened_at)) order_last_edited_at,
    count(distinct h.id) order_edit_count
FROM {{ ref('_int_product__edit_orders_orders') }} o
LEFT JOIN {{ source('int_orders', 'orders_edit_history') }} h on h.order_id = o.id
group by
o.id,
o.fecha_completed_at,
o.payment_status,
o.status,
o.gmv_usd,
o.year_month_day_code,
o.store_id,
was_order_edited