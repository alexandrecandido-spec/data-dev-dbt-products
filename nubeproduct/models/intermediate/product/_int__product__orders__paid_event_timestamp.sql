select 
order_id,
data_2 as status,
min(happened_at) as paid_order_timestamp
from {{ ref('product__orders__order_logging__event') }}  
where happened_at >= DATE('2025-01-01')
and data_2 = 'paid'
group by 1,2