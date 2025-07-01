select
    id,
    previous_total,
    total_delta,
    previous_total_usd,
    total_delta_usd,
    previous_subtotal,
    subtotal_delta,
    previous_subtotal_usd,
    subtotal_delta_usd,
    sys_audit_updated_on,
    sys_audit_updated_by
from {{ source('int_orders', 'orders_value_history') }}   
    where reason = 'EDITION'