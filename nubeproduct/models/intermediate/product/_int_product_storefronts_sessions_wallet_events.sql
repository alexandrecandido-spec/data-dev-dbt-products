select  
cart_id,
max(case when event = 'wallet_customer_identification' then 1 else 0 end) as wallet_customer_identification,
max(case when event = 'wallet_customer_login' then 1 else 0 end) as wallet_customer_login
from {{ ref('s__product_events_wallet__link') }} 
group by 1