{{ config(
    materialized='table',
    on_schema_change='fail',
    unique_key=['store_id', 'date'],
    tags=['daily-7am']
) }}

--Upsell Aquarium
with 
	--Success deals by store
	last_success_deal as 
		(select
      d.store_id,
      d.deal_id,
      d.stage,
      case when d.stage not in ('Out of portfolio','Effective churn') then true else false end as is_success,
      d.pipeline,
      d.pipeline_creation_date,
      date_entered_downgrade,
      row_number() over (
        partition by d.store_id
        order by d.pipeline_creation_date desc, d.deal_id desc
      ) as rn
		from {{ ref('s__success__pipeline__snapshot') }} d
		),
	-- Last Success deal
	success_store as 
		(select
			store_id,
			stage,
			is_success
		from last_success_deal
		where rn = 1
		),
	-- Downgrade based on last success deal
	downgrade_store as (
	  select
	    store_id,
	    true as is_downgrade,
	    date_entered_downgrade
	  from last_success_deal
	  where 
      rn = 1
	    and stage = 'Out of portfolio'
	),
   all_upsell_deals as (
     select
       d.store_id,
       d.deal_id,
       d.deal_owner                        as deal_owner_upsell,
       d.sales_dev_owner                   as sales_dev_responsible_upsell,
       d.acquisition_channel               as acquisition_channel_upsell,
       d.pipeline_creation_date            as creation_date_hubspot,
       d.closedate                         as close_date_hubspot,
       d.stage                             as deal_stage_hubspot,
       d.closed_lost_reason_1              as closed_lost_reason_1_hubspot,
       d.closed_lost_reason_2              as closed_lost_reason_2_hubspot,
       d.closed_lost_notes_sales           as closed_lost_notes_hubspot,
       d.sys_audit_updated_on              as last_update_hubspot,
       d.notes_last_updated                as last_activity_date,
       row_number() over (
         partition by store_id
         order by
           case when stage = 'Lost' then 0 else 1 end desc,   -- open / won first
           coalesce(closedate, pipeline_creation_date) desc,                  -- most recent
           d.deal_id desc                                         -- tiebreaker
       ) as rn
     from {{ ref('s__upsell__renewal__pipeline__snapshot') }} d
     where 
        d.store_id > 0
        and d.client_upsell_motive = 'Upsell'
   ),
   upsell_deal as (
     select *
     from all_upsell_deals
     where rn = 1
   ),
   --BR only: Stores with less than 100K in last three months
   gmv_under_100 as (
     select distinct
       f.store_id,
       true as gmv_under_100k_last_3m_br_only
     from {{ ref('company_metrics_gmv_and_segments') }} as f
     where
       datemonth in (
         select distinct datemonth
         from {{ ref('company_metrics_gmv_and_segments') }} as f2
         order by 1 desc
         limit 3
       )
       and f.gmv_local_currency_on_platform_monthly < 100000
       and f.country = 'BR'
   ),
   --BR only: Stores with more than 400K with less than 180 days antiquity
   gmv_over_400 as (
     select distinct
       f.store_id,
       true as gmv_over_400k_lt_180d_since_creation_br_only
     from {{ ref('company_metrics_gmv_and_segments') }} as f
     left join {{ ref('_int__midmarket__upsell_and_renewal_merchant_info') }} as si 
       on f.store_id = si.store_id
    where
      date_diff(DAY, date(si.store_creation_date), current_date) <= 180
      and f.country = 'BR'
      and f.gmv_local_currency_on_platform_monthly >= 400000
   )
select distinct
  f.store_id                                           as store_id,
  --Store info
  si.store_creation_date                               as created_at,
  si.days_since_store_creation                         as days_since_store_creation,
  si.store_antiquity                                   as store_antiquity,
  si.domain                                            as domain,
  si.country                                           as country,
  si.vertical                                          as vertical,
  si.current_segment                                   as current_segment,
  si.user_email                                        as mail,
  si.owner_phone                                       as phone,
  si.owner_phone_number                                as owner_phone_number,
  si.risk_dropshipping_tag                             as risk_dropshipping,
  si.franchise_group                                   as franchise_group,
  si.current_plan                                      as plan_name,
  --Location data
  si.region_name                                       as region,
  si.state_name                                        as state,
  si.city_name                                         as city,
  --Success info
  coalesce(sus.is_success, false)                      as is_success,
  coalesce(ds.is_downgrade, false)                     as is_success_downgrade,
  ds.date_entered_downgrade                            as date_entered_downgrade,
  --Upsell info
  coalesce(ud.deal_stage_hubspot, 'Not contacted')     as deal_stage_hubspot,
  ud.creation_date_hubspot,
  ud.close_date_hubspot,
  ud.closed_lost_reason_1_hubspot,
  ud.closed_lost_reason_2_hubspot,
  ud.closed_lost_notes_hubspot,
  ud.deal_owner_upsell,
  ud.sales_dev_responsible_upsell,
  ud.last_activity_date,
  ud.last_update_hubspot,
  --Finance info
  date_trunc('month', f.datemonth)                     as datemonth,
  f.is_paying_merchant                                 as is_paying_merchant,
  f.orders_on_platform_monthly                         as total_orders_on_platform,
  round(f.gmv_usd_on_platform_monthly)                 as total_gmv_usd_on_platform,
  round(f.gmv_local_currency_on_platform_monthly)      as total_gmv_local_currency_on_platform,
  f.segment_on_platform                                as segment_on_platform,
  --GMV filters
  case 
    when si.country = 'BR' then coalesce(gu100.gmv_under_100k_last_3m_br_only, false)
  end                                                  as gmv_under_100k_last_3m_br_only,
  case 
    when si.country = 'BR' then coalesce(go400.gmv_over_400k_lt_180d_since_creation_br_only, false)
  end                                                  as gmv_over_400k_lt_180d_since_creation_br_only,
  current_timestamp                                    as sys_audit_created_on,
  'data-dev-dbt-products'                              as sys_audit_created_by,
  current_timestamp                                    as sys_audit_updated_on,
  'data-dev-dbt-products'                              as sys_audit_updated_by
from {{ ref('company_metrics_gmv_and_segments') }} as f
left join {{ ref('_int__midmarket__upsell_and_renewal_merchant_info') }} as si 
  on f.store_id = si.store_id
left join success_store as sus
  on f.store_id = sus.store_id
left join downgrade_store as ds
  on f.store_id = ds.store_id
left join upsell_deal as ud
  on f.store_id = ud.store_id
left join gmv_under_100 as gu100
  on f.store_id = gu100.store_id
left join gmv_over_400 as go400
  on f.store_id = go400.store_id
where
  f.datemonth >= date '2023-01-01'
  and f.store_id not in (
    select store_id
    from upsell_deal
    where closed_lost_reason_2_hubspot = '2) Out of Target (ICP): E-commerce sells unlicensed, counterfeit products or prohibited'
  )
  and si.country in ('AR','BR','MX')
  and si.is_store_blocked is false
  and si.store_churn_date is null
  and si.first_payment is not null
  and si.state <> 4
  and (si.current_plan != 'enterprise')
  and (sus.stage != 'Effective churn' or sus.stage is null)