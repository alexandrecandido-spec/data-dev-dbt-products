WITH store_source AS (
  SELECT
    si.store_id
    , si.state
    , si.created_at
    , si.domain
    , si.country AS country_code
    , si.currency
    , CASE 
      WHEN si.verified = 0 THEN 'undefined'
      WHEN si.verified = 1 THEN 'desktop'
      WHEN si.verified = 2 THEN 'app'
      WHEN si.verified IN (4,5,6) THEN 'mobile'
      ELSE 'tablet'
      END AS device
    , si.register_url
    , si.partner_id
    , si.partnership_type
    , si.sys_audit_updated_on
  FROM {{ ref('merchant__attributes__store_info__ref') }} si
), 
location_info AS (
  SELECT
    loc.store_id
    , lcr.country_name
    , lrr.region_name
    , lsr.state_name
    , lcr.city_name
    , loc.sys_audit_updated_on
  FROM {{ ref('dimension__attributes__location_by_zipcode__link') }} loc
  LEFT JOIN {{ ref('dimension__attributes__location_country__ref') }} lcr ON loc.country_id = lcr.country_id
  LEFT JOIN {{ ref('dimension__attributes__location_region__ref') }} lrr ON loc.region_id = lrr.region_id
  LEFT JOIN {{ ref('dimension__attributes__location_state__ref') }} lsr ON loc.state_id = lsr.state_id
  LEFT JOIN {{ ref('dimension__attributes__location_city__ref') }} lcr ON loc.city_id = lcr.city_id
),
vertical_info AS (
  SELECT 
    vv.store_id
    , vv.vertical_name
    , vv.sys_audit_updated_on
  FROM {{ ref('dimension__attributes__vertifier_and_vertical__ref') }} vv 
),
business_size_info AS (
  SELECT
    bs.store_id
    , bsr.business_size_name
    , bs.sys_audit_updated_on
  FROM {{ ref('dimension__attributes__business_size__link') }} bs
  LEFT JOIN {{ ref('dimension__attributes__business_size__ref') }} bsr ON bs.business_size_id = bsr.business_size_id
),
partner_info AS (
  SELECT
    p.partner_id
    , p.partner_code
    , p.sys_audit_updated_on
  FROM {{ ref('partnerships__general__partners__ref') }} p
),
register_plan AS (
  SELECT
    rp.id as store_id
    , rp.plan_chosen_on_register as register_plan_id
    , CASE WHEN rp.plan_chosen_on_register=0 THEN 'freemium' ELSE gp.grupo END as register_plan_type
  FROM {{ source('stg_moltres','mwp_store_info') }} rp
  LEFT JOIN {{ ref('operations_grouping_plans') }} gp ON rp.plan_chosen_on_register = gp.plan
)


SELECT 
    ss.store_id
    , ss.state
    , ss.created_at
    , ss.domain
    , ss.country_code
    , dc.country_name
    , COALESCE(li.region_name, 'not informed') as region_name
    , COALESCE(li.state_name, 'not informed') as state_name
    , COALESCE(li.city_name, 'not informed') as city_name
    , ss.currency
    , ss.device
    , ss.register_url
    , rp.register_plan_type
    , ss.partner_id
    , ss.partnership_type
    , pi.partner_code
    , COALESCE(vi.vertical_name, 'not informed') as vertical_name
    , COALESCE(bs.business_size_name, 'not informed') as business_size_name
    , greatest(ss.sys_audit_updated_on, li.sys_audit_updated_on, vi.sys_audit_updated_on, bs.sys_audit_updated_on, pi.sys_audit_updated_on) as change_timestamp
FROM store_source ss 
LEFT JOIN location_info li ON ss.store_id = li.store_id
LEFT JOIN vertical_info vi ON ss.store_id = vi.store_id
LEFT JOIN business_size_info bs ON ss.store_id = bs.store_id
LEFT JOIN partner_info pi ON ss.partner_id = pi.partner_id
LEFT JOIN {{ ref('dimension__attributes__location_country__ref') }} dc ON ss.country_code = dc.country_code
LEFT JOIN register_plan rp ON ss.store_id = rp.store_id