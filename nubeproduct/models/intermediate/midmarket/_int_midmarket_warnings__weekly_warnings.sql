with warnings as (
  select 
      CAST(date_trunc('week', current_date) - interval '7' day AS DATE) as date_from,
      CAST(date_trunc('week', current_date) AS DATE) as date_to,
      d.deal_id,
      d.store_id,
      d.warning_root_cause_1,
      d.warning_root_cause_2,
      d.warning_summary,
      d.warning_type,
      d.competitor_identified,
      CAST(coalesce(d.date_entered_warning_br,
          coalesce(d.date_entered_warning_ar, d.date_entered_warning_mx)) AS DATE) as date_entered_warning,
      CAST(coalesce(d.date_exited_warning_br,
          coalesce(d.date_exited_warning_ar, d.date_exited_warning_mx)) AS DATE) as date_exited_warning
  from 
      {{ source('int_third_party', 'midmarket_hubspot_deals') }} d 
      inner join {{ ref('midmarket_success_stores') }} ss 
          on d.deal_id = ss.deal_id
)

select 
  *
from 
  warnings w 
where 
  date_entered_warning is not null