--Adoption store level 
WITH orders_auto_cancel_configuration AS (
SELECT
    config.store_id,
    date(config.created_at) first_config_at,
    config.update_stock,
    config.pre_notify_client,
    config.notify_client,
    config.active AS overall_active,
    coalesce(date(config.activated_at), date(config.deactivated_at)) AS last_overall_change_at,
    -- Extract paymentStatus from the parsed JSON
    parsed_config.paymentStatus,
    -- Extract fields from the exploded payment methods
    t.active AS payment_method_active,
    coalesce(date(to_timestamp(regexp_replace(t.activatedAt, 'T|Z', ' '))), date(to_timestamp(regexp_replace(t.deactivatedAt, 'T|Z', ' ')))) AS last_change_at,
    t.paymentMethod,
    t.expirationTime,
    sys_audit_updated_on acc_sys_audit_updated_on
FROM {{source('int_orders', 'orders_auto_cancel_configuration')}} config
LATERAL VIEW
      EXPLODE(
        from_json(
          config.expiration_time_configuration,
          'ARRAY<STRUCT<paymentStatus: STRING, paymentMethods: ARRAY<STRUCT<active: BOOLEAN, paymentMethod: STRING, activatedAt: STRING, deactivatedAt: STRING, expirationTime: INT>>>>'
        )
      ) exploded_json AS parsed_config
    LATERAL VIEW
      EXPLODE(parsed_config.paymentMethods) AS t
)

select
concat(i.store_id,coalesce(c.paymentStatus,""),coalesce(c.paymentMethod,"")) as unique_key,
i.store_id,
i.state,
i.current_segment,
i.country,
gp.grupo plan,
apps.has_nuvempago,
apps.has_pagonube,
case when c.store_id is not null then true else false end as has_configed_feature,
c.first_config_at,
c.overall_active,
c.last_overall_change_at,
c.update_stock,
c.pre_notify_client,
c.notify_client,
c.overall_active,
c.paymentStatus payment_status,
c.payment_method_active,
c.last_change_at,
c.paymentMethod payment_method,
c.expirationTime expiration_time,
GREATEST(
        COALESCE(i.sys_audit_updated_on, '1900-01-01'),
        COALESCE(apps.cmpo_sys_audit_updated_on, '1900-01-01'),
        COALESCE(gp.sys_audit_updated_on, '1900-01-01'),
        COALESCE(c.acc_sys_audit_updated_on, '1900-01-01')
    ) as max_sys_audit_updated_on

from {{ ref('moltres__mwp_store_info') }} i
left join 
 (
 select distinct
 store_id,
case when payment='pago-nube' then true end as has_pagonube,
case when payment='nuvem-pago' then true end as has_nuvempago,
max(sys_audit_updated_on) cmpo_sys_audit_updated_on
from {{ ref('company_metrics_paid_orders') }} cmpo
WHERE 
 payment IN ('nuvem-pago','pago-nube')
and 
  TO_DATE(cast(year_month_day_code as string), 'yyyyMMdd') >= DATE_SUB(current_date(), 365)
  group by 1,2,3
 ) apps ON apps.store_id = i.store_id
LEFT JOIN 
    {{ ref('operations_grouping_plans') }} gp on gp.plan = i.plan
left join 
  orders_auto_cancel_configuration c on c.store_id = i.store_id