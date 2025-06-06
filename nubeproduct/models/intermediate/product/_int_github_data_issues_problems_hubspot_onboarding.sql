select 
d.store_id, 
case when d.pipeline = 'Onboarding | AR' then 'AR'
                            when d.pipeline = 'Onboarding | BR' then 'BR'
                            when d.pipeline = 'Onboarding | MX' then 'MX' 
                            else 'NA' 
                            end as country,
d.sys_audit_updated_on
from {{ source('int_third_party', 'midmarket_hubspot_deals') }} d
where pipeline in ('Onboarding | AR','Onboarding | BR','Onboarding | MX')
                            and dealstage not in ('Transition to Customer Success','Churn','Downgrade de plan','Downgrade de plano')
                            and store_id <> 0 and store_id is not null