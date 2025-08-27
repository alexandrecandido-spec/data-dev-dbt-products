-- Owner: Guille De Felice

select 
    d.deal_id,
    TRIM(regexp_replace(success_priority, '^[^a-zA-Z0-9]*', '')) AS success_priority
from
    {{ source('int_third_party', 'midmarket_hubspot_deals') }} d
    inner join {{ ref('midmarket_success_stores') }} s
        on d.deal_id = s.deal_id