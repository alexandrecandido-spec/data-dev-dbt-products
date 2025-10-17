with stores as (
    select
      date_trunc('month',created_at) as month_creation_date
      ,partner_id
      ,count(distinct store_id) as total_referred_stores
      ,count(distinct case when first_payment is not null 
                           and state != 4
                           then store_id 
            end) as total_referred_payment_stores
    from {{ ref ('moltres__mwp_store_info') }}
    where partner_id is not null
    group by 1,2
)
SELECT
*
from stores

