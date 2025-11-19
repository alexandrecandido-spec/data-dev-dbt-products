with
   --Franchise group
	franchise as 
		(select
		    t.related_id as store_id,
		    lower(t.tag) as franchise_group
		from {{ source('int_moltres', 'mwp_tags') }} t
			inner join
					(select
					    t.related_id as store_id,
					    max(t.created) as last_creation_date
					from {{ source('int_moltres', 'mwp_tags') }} t
					where
					    lower(t.tag) like 'group-%'
					group by 1) as lt
			    on t.related_id = lt.store_id
			    and t.created = lt.last_creation_date
		where
		    lower(t.tag) like 'group-%'),
    --Tag risk dropshipping
    risk_tag as 
        (select distinct
            related_id as store_id,
            true as risk_dropshipping_tag
        from {{ source('int_moltres', 'mwp_tags') }} t
        where 
            t.tag = 'risk-dropshipping')
select
	sa.store_id,
	cast(sa.created_at as date) as store_creation_date,
    date_diff(DAY, date(sa.created_at), current_date) as days_since_store_creation,
    case
    	when date_diff(DAY, date(sa.created_at), current_date) >= 180 then '180 days or more'
    	when date_diff(DAY, date(sa.created_at), current_date) < 180 then 'Less than 180 days'
    end store_antiquity,
	sa.domain,
	sa.country_code as country,
	sa.region_name,
	sa.state_name,
	sa.city_name,
	sa.vertical_name as vertical,
	ss.state,
    ss.current_plan_type as current_plan,
    ss.current_segment,
    cast(ss.first_payment as date) as first_payment,
    cast(ss.churned_at as date) as store_churn_date,
    sid.user_email, 
    sid.owner_phone, 
    sid.owner_phone_number,
    sid.store_name,
    fg.franchise_group,
	rt.risk_dropshipping_tag,
    ss.is_store_blocked
from {{ ref('s__attributes__store_core__ref') }} as sa
	left join {{ ref('s__attributes__store_identity__ref')}} as sid
		on sa.store_id = sid.store_id
	left join {{ ref('s__lifecycle__store_status__ref')}} as ss
		on sa.store_id = ss.store_id
	left join franchise as fg
		on sa.store_id = fg.store_id
	left join risk_tag as rt
		on sa.store_id = rt.store_id