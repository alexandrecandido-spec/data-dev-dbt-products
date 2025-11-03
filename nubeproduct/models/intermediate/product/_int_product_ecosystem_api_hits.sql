select
    a.registered_date
    ,i.app_id
    ,i.store_id
    ,sum(a.api_hits) as total_api_hits
from {{ ref('product__ecosystem__api_hits__snapshot_daily') }} a
inner join {{ ref('moltres__platform_mwp_apps_stores') }} i
    on a.installed_app_id = i.installed_app_id
group by 1,2,3