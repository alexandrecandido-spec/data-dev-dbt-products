with
    --Unique store name
    store_names as 
        (select distinct
			si.id as store_id,
			ssi.name as store_name
		from {{ source('int_moltres', 'mwp_store_info') }} as si
			left join {{ source('int_moltres', 'mwp_store_settings') }} as ss
				on si.id = ss.store_id
			left join {{ source('int_moltres', 'mwp_store_settings_i18n') }} as ssi
				on ss.id = ssi.store_setting_id
		where
			si.country = substring(ssi.lang,INSTR(ssi.lang,'_')+1,2)),
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
            t.tag = 'risk-dropshipping'),
	--Blocked stores
	blocked_stores as
		(select distinct 
			t.related_id as store_id,
            true as blocked_store_tag
		from {{ source('int_moltres', 'mwp_tags') }} as t
		  where
		  	t.type = 'store' 
		  	and 
		  		(t.tag = 'sre-block-store-429'
		  		or 
		  		t.tag = 'sre-block-store-404'))
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
    --store_info
	si.state,
    p.grupo as current_plan,
    si.current_segment,
    cast(si.first_payment as date) as first_payment,
    cast(si.churned_at as date) as store_churn_date,
    --store_settings
    ss.mail, 
    ss.phone, 
    ss.owner_phone_number,
    sn.store_name,
    fg.franchise_group,
	rt.risk_dropshipping_tag,
    bs.blocked_store_tag
from {{ ref('s__attributes__store_core__ref') }} as sa
    left join {{ source('int_moltres', 'mwp_store_info') }} as si
    	on sa.store_id = si.id
    left join {{ source('int_moltres', 'mwp_store_settings') }} as ss
        on sa.store_id = ss.store_id
	left join {{ ref('operations_grouping_plans') }} as p
    	on si.plan = p.plan    
    left join store_names as sn
    	on sa.store_id = sn.store_id
	left join franchise as fg
		on sa.store_id = fg.store_id
	left join risk_tag as rt
		on sa.store_id = rt.store_id
    left join blocked_stores as bs
		on sa.store_id = bs.store_id