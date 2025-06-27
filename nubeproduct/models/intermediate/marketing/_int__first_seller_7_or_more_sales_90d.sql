select
    store_id,
    completed_at
from {{ ref('orders_with_window') }}
where sales_90d >= 7