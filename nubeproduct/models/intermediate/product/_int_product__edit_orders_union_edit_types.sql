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
    extra as extra
from {{ source('int_edit_orders', 'orders_edit_history_discounts') }} 

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
    null as extra
from {{ source('int_edit_orders', 'orders_edit_history_products') }} 