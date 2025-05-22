select 
d.store_id, 
case when d.pipeline = 'Onboarding | AR' then 'AR'
                            when d.pipeline = 'Onboarding | BR' then 'BR'
                            when d.pipeline = 'Onboarding | MX' then 'MX' 
                            else 'NA' 
                            end as country
from {{ source('int_third_party', 'midmarket_hubspot_deals') }} d
