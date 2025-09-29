-- Owner: Guille De Felice

select
    gas.store_id,
    datemonth,
    gmv_local_currency_on_platform_90d,
    ROUND(gmv_usd_on_platform_90d, 2) as gmv_usd_on_platform_90d,
    case
        when country = 'BR' and gmv_local_currency_on_platform_90d/3 <400000
        then 'Tier 3'
        when country = 'BR' and gmv_local_currency_on_platform_90d/3 >=400000 and gmv_local_currency_on_platform_90d/3 <800000
        then 'Tier 2'
        when country = 'BR' and gmv_local_currency_on_platform_90d/3 >=800000
        then 'Tier 1'
        when country in ('AR','MX') and gmv_usd_on_platform_90d/3 <60000
        then 'Tier 3'
        when country in ('AR','MX') and gmv_usd_on_platform_90d/3 >=60000 and gmv_usd_on_platform_90d/3 <120000
        then 'Tier 2'
        when country in ('AR','MX') and gmv_usd_on_platform_90d/3 >=120000
        then 'Tier 1'
        else ''
    end as gmv_tier
from 
    {{ ref('company_metrics_gmv_and_segments') }} gas
    inner join {{ ref('midmarket_success_stores') }} s
        on gas.store_id = s.store_id