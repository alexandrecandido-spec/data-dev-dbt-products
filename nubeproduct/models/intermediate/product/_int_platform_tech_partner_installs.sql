with
installs as(
   SELECT
      store_id
      ,a.app_id
      ,e.partner_id
      ,app_install_date
      ,app_uninstall_date
   from {{ ref('product_platform_mwp_apps_stores') }} a
   left join {{ ref('product__ecosystem__apps__scd') }} e
      on a.app_id = e.app_id
)
SELECT
   date_trunc('month',app_install_date) as month_install_date
   ,partner_id
   ,app_id
   ,count(distinct store_id) as total_installs
   ,count(distinct case when app_uninstall_date is not null then store_id end) as total_installs_active
from installs
group by 1,2,3