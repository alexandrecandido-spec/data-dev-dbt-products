-- Owner: Guille De Felice

select 
    c.store_id, 
    contract_end_date
from 
    {{ source('int_hubspot', 'companies') }} c
    inner join {{ ref('midmarket_success_stores') }} s
        on c.store_id = s.store_id
where 
    c.store_id > 0