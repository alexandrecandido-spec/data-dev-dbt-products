-- Owner: Guille De Felice

with ranked_companies as (
    select 
        c.store_id, 
        contract_end_date,
        ROW_NUMBER() OVER (PARTITION BY c.store_id ORDER BY c.createdate DESC, updatedAt DESC) AS rn
    from 
        {{ source('int_hubspot', 'companies') }} c
        inner join {{ ref('midmarket_success_stores') }} s
            on c.store_id = s.store_id
    where 
        c.store_id > 0
)

select 
    store_id,
    contract_end_date
from 
    ranked_companies
where 
    rn = 1