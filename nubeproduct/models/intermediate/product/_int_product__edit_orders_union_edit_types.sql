select 
    id,
    store_id,
    order_id,
    edit_id,
    discount_type as edit_type,
    discount_action edit_action,
    amount,
    amount_usd, 
    null as line_item_id,
    null as previous_product_qty,
    null as new_product_qty,
    extra as extra,
    null as happened_at,
    sys_audit_updated_on,
    sys_audit_updated_by
from {{ source('int_orders', 'orders_edit_history_discounts') }} 

union all

select 
    id,
    store_id,
    order_id,
    id as edit_id,
    type as edit_type,
    data_2 edit_action,
    null as amount,
    null as amount_usd, 
    null as line_item_id,
    null as previous_product_qty,
    null as new_product_qty,
    null as extra,
    cast(happened_at as date)  as happened_at,
    sys_audit_updated_on,
    sys_audit_updated_by
from {{ source('int_orders', 'mwp_orders_logging') }} 
where type = 'shipping-address' and year_month_code >= CAST(date_format(date_add(MONTH, -7, current_date),'yyyyMM') AS INTEGER)

union all

select 
    id,
    store_id,
    order_id,
    edit_id, 
    'product' as edit_type,
    type as edit_action, 
    null as amount,
    null as amount_usd,
    line_item_id,
    previous_quantity as previous_product_qty,
    new_quantity as new_product_qty,
    null as extra,
    null as happened_at,
    sys_audit_updated_on,
    sys_audit_updated_by
from {{ source('int_orders', 'orders_edit_history_products') }} 