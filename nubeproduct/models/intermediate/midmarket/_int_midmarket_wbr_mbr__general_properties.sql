-- Owner: Guille De Felice

select 
    s.store_id,
    d.where_did_the_lead_came_from_ as lead_source,
    d.deal_tags,
    d.gmv_potencial,
    d.data_go_live,
    d.type_of_onboarding as onboarding_type,
    CAST(d.createdate AS DATE) as createdate
from
    {{ source('int_third_party', 'midmarket_hubspot_deals') }} d
    inner join {{ ref('midmarket_success_stores') }} s
        on d.deal_id = s.deal_id