select 
    distinct d.hubspot_owner_id
from 
    {{ source('int_third_party', 'midmarket_hubspot_deals') }} d
    inner join {{ ref('midmarket_success_stores') }} ss
        on d.deal_id = ss.deal_id