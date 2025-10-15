select 
    o.id,
    o.order_completed_at,
    o.payment_status,
    o.status,
    o.gmv_usd,
    o.order_year_month_day_code,
    o.store_id,
    min(date(happened_at)) order_first_edited_at,
    max(date(happened_at)) order_last_edited_at,
    count(distinct h.id) order_edit_count,
    -- Combined audit field for all sources in this model
    GREATEST(
        COALESCE(max(o.sys_audit_updated_on), '1900-01-01'),
        COALESCE(max(h.sys_audit_updated_on), '1900-01-01')
    ) as max_sys_audit_updated_on
FROM {{ ref('_int_product__edit_orders_orders') }} o
LEFT JOIN {{ source('int_orders', 'orders_edit_history') }} h on h.order_id = o.id
group by
o.id,
o.order_completed_at,
o.payment_status,
o.status,
o.gmv_usd,
o.order_year_month_day_code,
o.store_id
