select
    store_id,
    completed_at
from {{ ref('_int__first_seller_orders_with_window') }}
where sales_90d >= 7