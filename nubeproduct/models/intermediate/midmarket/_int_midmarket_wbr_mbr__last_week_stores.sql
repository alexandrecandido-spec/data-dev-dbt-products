-- Owner: Guille De Felice

select 
    store_id
from 
    {{ source("int_midmarket", "midmarket_weekly_business_review") }}
where 
    date_from = (SELECT max(date_from) FROM {{ source("int_midmarket", "midmarket_weekly_business_review") }})
    and playbook not in ('Effective churn', 'Out of portfolio')
