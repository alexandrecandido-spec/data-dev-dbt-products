select 
a.store_id,
msi.domain as store_domain,
msi.state,
msi.country,
msi.current_segment,
gp.grupo plan_name,
case 
    when a.app_id is null then 0
    else 1
end as created_by_app,
gmv.avg_gmv_usd_last_3m as avg_gmv_usd_last_3m,
a.name as name_mf,
a.uuid,
case 
    when a.value_type = 1 then 'Option list'
    when a.value_type = 2 then 'Text'
    when a.value_type = 3 then 'Number'
    when a.value_type = 4 then 'Date'
end as metafield_data_type,
case 
    when date(a.deleted_at) is null or date(a.deleted_at) = date('1970-01-01') then 1
    else 0
end mf_is_active,
case
    when a.value_type = 1 and opt_l.metafield_uuid is null then 0
    when a.value_type = 1 and opt_l.metafield_uuid is not null then 1
    when a.value_type = 2 and txt.metafield_uuid is null then 0
    when a.value_type = 2 and txt.metafield_uuid is not null then 1
    when a.value_type = 3 and num.metafield_uuid is null then 0
    when a.value_type = 3 and num.metafield_uuid is not null then 1
    when a.value_type = 4 and dt.metafield_uuid is null then 0
    when a.value_type = 4 and dt.metafield_uuid is not null then 1
end mf_is_assigned,
date(a.created_at) metafield_created_at,
'Product variants' as domain,
COALESCE(opt_l.id, dt.id, num.id, txt.id) as assignment_id,
COALESCE(opt_l.owner_id, dt.owner_id, num.owner_id, txt.owner_id) as owner_id,
case
    when a.value_type = 1 and date(opt_l.created_at) <> date('1970-01-01') then date(opt_l.created_at)
    when a.value_type = 2 and date(txt.created_at) <> date('1970-01-01') then date(txt.created_at)
    when a.value_type = 3 and date(num.created_at) <> date('1970-01-01') then date(num.created_at)
    when a.value_type = 4 and date(dt.created_at) <> date('1970-01-01') then date(dt.created_at)
end as assignment_date,
GREATEST(
    a.sys_audit_updated_on,
    opt_l.sys_audit_updated_on,
    dt.sys_audit_updated_on,
    num.sys_audit_updated_on,
    txt.sys_audit_updated_on,
    msi.sys_audit_updated_on,
    gp.sys_audit_updated_on,
    gmv.gmv_max_sys_audit_updated_on
) AS max_sys_audit_updated_on
from {{ref('product__metafield__product_variants__event')}} a 
left join {{ref('product__metafield__option_resource_product_variants__event')}} opt_l 
on opt_l.metafield_uuid = a.uuid
left join {{ref('product__metafield__date_resource_product_variants__event')}} dt 
on dt.metafield_uuid = a.uuid
left join {{ref('product__metafield__numeric_resource_product_variants__event')}} num
on num.metafield_uuid = a.uuid
left join {{ref('product__metafield__text_resource_product_variants__event')}} txt
on txt.metafield_uuid = a.uuid
left join {{ref('moltres__mwp_store_info')}} as msi
on a.store_id = msi.store_id
left join {{ref('operations_grouping_plans')}} gp on gp.plan = msi.plan
left join 
(    SELECT
        store_id,
        round(avg(gmv_usd_monthly),2) AS avg_gmv_usd_last_3m,
        round(avg(orders_monthly)) AS avg_orders_last_3m,
        MAX(sys_audit_updated_on) AS gmv_max_sys_audit_updated_on
    FROM {{ref('company_metrics_gmv_and_segments')}}
    WHERE trunc(datemonth, 'MM') BETWEEN add_months(trunc((SELECT max(datemonth) FROM {{ref('company_metrics_gmv_and_segments')}}), 'MM'),-2)
        AND trunc((SELECT max(datemonth) FROM {{ref('company_metrics_gmv_and_segments')}}), 'MM')
    GROUP BY 1) AS gmv
on a.store_id = gmv.store_id
where 1=1
and a.deleted_at is null
and msi.churned_at is null
and msi.state not in (3,4)

UNION
select 
a.store_id,
msi.domain as store_domain,
msi.state,
msi.country,
msi.current_segment,
gp.grupo plan_name,
case 
    when a.app_id is null then 0
    else 1
end as created_by_app,
gmv.avg_gmv_usd_last_3m as avg_gmv_usd_last_3m,
a.name as name_mf,
a.uuid,
case 
    when a.value_type = 1 then 'Option list'
    when a.value_type = 2 then 'Text'
    when a.value_type = 3 then 'Number'
    when a.value_type = 4 then 'Date'
end as metafield_data_type,
case 
    when date(a.deleted_at) is null or date(a.deleted_at) = date('1970-01-01') then 1
    else 0
end mf_is_active,
case
    when a.value_type = 1 and opt_l.metafield_uuid is null then 0
    when a.value_type = 1 and opt_l.metafield_uuid is not null then 1
    when a.value_type = 2 and txt.metafield_uuid is null then 0
    when a.value_type = 2 and txt.metafield_uuid is not null then 1
    when a.value_type = 3 and num.metafield_uuid is null then 0
    when a.value_type = 3 and num.metafield_uuid is not null then 1
    when a.value_type = 4 and dt.metafield_uuid is null then 0
    when a.value_type = 4 and dt.metafield_uuid is not null then 1
end mf_is_assigned,
date(a.created_at) metafield_created_at,
'Orders' as domain,
COALESCE(opt_l.id, dt.id, num.id, txt.id) as assignment_id,
COALESCE(opt_l.owner_id, dt.owner_id, num.owner_id, txt.owner_id) as owner_id,
case
    when a.value_type = 1 and date(opt_l.created_at) <> date('1970-01-01') then date(opt_l.created_at)
    when a.value_type = 2 and date(txt.created_at) <> date('1970-01-01') then date(txt.created_at)
    when a.value_type = 3 and date(num.created_at) <> date('1970-01-01') then date(num.created_at)
    when a.value_type = 4 and date(dt.created_at) <> date('1970-01-01') then date(dt.created_at)
end as assignment_date,
GREATEST(
    a.sys_audit_updated_on,
    opt_l.sys_audit_updated_on,
    dt.sys_audit_updated_on,
    num.sys_audit_updated_on,
    txt.sys_audit_updated_on,
    msi.sys_audit_updated_on,
    gp.sys_audit_updated_on,
    gmv.gmv_max_sys_audit_updated_on
) AS max_sys_audit_updated_on
from {{ref('product__metafield__orders__event')}} a 
left join {{ref('product__metafield__option_resource_orders__event')}} opt_l 
on opt_l.metafield_uuid = a.uuid
left join {{ref('product__metafield__date_resource_orders__event')}} dt 
on dt.metafield_uuid = a.uuid
left join {{ref('product__metafield__numeric_resource_orders__event')}} num
on num.metafield_uuid = a.uuid
left join {{ref('product__metafield__text_resource_orders__event')}} txt
on txt.metafield_uuid = a.uuid
left join {{ref('moltres__mwp_store_info')}} as msi
on a.store_id = msi.store_id
left join {{ref('operations_grouping_plans')}} gp on gp.plan = msi.plan
left join 
(    SELECT
        store_id,
        round(avg(gmv_usd_monthly),2) AS avg_gmv_usd_last_3m,
        round(avg(orders_monthly)) AS avg_orders_last_3m,
        MAX(sys_audit_updated_on) AS gmv_max_sys_audit_updated_on
    FROM {{ref('company_metrics_gmv_and_segments')}}
    WHERE trunc(datemonth, 'MM') BETWEEN add_months(trunc((SELECT max(datemonth) FROM {{ref('company_metrics_gmv_and_segments')}}), 'MM'),-2)
        AND trunc((SELECT max(datemonth) FROM {{ref('company_metrics_gmv_and_segments')}}), 'MM')
    GROUP BY 1) AS gmv
on a.store_id = gmv.store_id
where 1=1
and a.deleted_at is null
and msi.churned_at is null
and msi.state not in (3,4)
UNION
select 
a.store_id,
msi.domain as store_domain,
msi.state,
msi.country,
msi.current_segment,
gp.grupo plan_name,
case 
    when a.app_id is null then 0
    else 1
end as created_by_app,
gmv.avg_gmv_usd_last_3m as avg_gmv_usd_last_3m,
a.name as name_mf,
a.uuid,
case 
    when a.value_type = 1 then 'Option list'
    when a.value_type = 2 then 'Text'
    when a.value_type = 3 then 'Number'
    when a.value_type = 4 then 'Date'
end as metafield_data_type,
case 
    when date(a.deleted_at) is null or date(a.deleted_at) = date('1970-01-01') then 1
    else 0
end mf_is_active,
case
    when a.value_type = 1 and opt_l.metafield_uuid is null then 0
    when a.value_type = 1 and opt_l.metafield_uuid is not null then 1
    when a.value_type = 2 and txt.metafield_uuid is null then 0
    when a.value_type = 2 and txt.metafield_uuid is not null then 1
    when a.value_type = 3 and num.metafield_uuid is null then 0
    when a.value_type = 3 and num.metafield_uuid is not null then 1
    when a.value_type = 4 and dt.metafield_uuid is null then 0
    when a.value_type = 4 and dt.metafield_uuid is not null then 1
end mf_is_assigned,
date(a.created_at) metafield_created_at,
'Products' as domain,
COALESCE(opt_l.id, dt.id, num.id, txt.id) as assignment_id,
COALESCE(opt_l.owner_id, dt.owner_id, num.owner_id, txt.owner_id) as owner_id,
case
    when a.value_type = 1 and date(opt_l.created_at) <> date('1970-01-01') then date(opt_l.created_at)
    when a.value_type = 2 and date(txt.created_at) <> date('1970-01-01') then date(txt.created_at)
    when a.value_type = 3 and date(num.created_at) <> date('1970-01-01') then date(num.created_at)
    when a.value_type = 4 and date(dt.created_at) <> date('1970-01-01') then date(dt.created_at)
end as assignment_date,
GREATEST(
    a.sys_audit_updated_on,
    opt_l.sys_audit_updated_on,
    dt.sys_audit_updated_on,
    num.sys_audit_updated_on,
    txt.sys_audit_updated_on,
    msi.sys_audit_updated_on,
    gp.sys_audit_updated_on,
    gmv.gmv_max_sys_audit_updated_on
) AS max_sys_audit_updated_on
from {{ref('product__metafield__products__event')}} a 
left join {{ref('product__metafield__option_resource_products__event')}} opt_l 
on opt_l.metafield_uuid = a.uuid
left join {{ref('product__metafield__date_resource_products__event')}} dt 
on dt.metafield_uuid = a.uuid
left join {{ref('product__metafield__numeric_resource_products__event')}} num
on num.metafield_uuid = a.uuid
left join {{ref('product__metafield__text_resource_products__event')}} txt
on txt.metafield_uuid = a.uuid
left join {{ref('moltres__mwp_store_info')}} as msi
on a.store_id = msi.store_id
left join {{ref('operations_grouping_plans')}} gp on gp.plan = msi.plan
left join 
(    SELECT
        store_id,
        round(avg(gmv_usd_monthly),2) AS avg_gmv_usd_last_3m,
        round(avg(orders_monthly)) AS avg_orders_last_3m,
        MAX(sys_audit_updated_on) AS gmv_max_sys_audit_updated_on
    FROM {{ref('company_metrics_gmv_and_segments')}}
    WHERE trunc(datemonth, 'MM') BETWEEN add_months(trunc((SELECT max(datemonth) FROM {{ref('company_metrics_gmv_and_segments')}}), 'MM'),-2)
        AND trunc((SELECT max(datemonth) FROM {{ref('company_metrics_gmv_and_segments')}}), 'MM')
    GROUP BY 1) AS gmv
on a.store_id = gmv.store_id
where 1=1
and a.deleted_at is null
and msi.churned_at is null
and msi.state not in (3,4)
UNION
select 
a.store_id,
msi.domain as store_domain,
msi.state,
msi.country,
msi.current_segment,
gp.grupo plan_name,
case 
    when a.app_id is null then 0
    else 1
end as created_by_app,
gmv.avg_gmv_usd_last_3m as avg_gmv_usd_last_3m,
a.name as name_mf,
a.uuid,
case 
    when a.value_type = 1 then 'Option list'
    when a.value_type = 2 then 'Text'
    when a.value_type = 3 then 'Number'
    when a.value_type = 4 then 'Date'
end as metafield_data_type,
case 
    when date(a.deleted_at) is null or date(a.deleted_at) = date('1970-01-01') then 1
    else 0
end mf_is_active,
case
    when a.value_type = 1 and opt_l.metafield_uuid is null then 0
    when a.value_type = 1 and opt_l.metafield_uuid is not null then 1
    when a.value_type = 2 and txt.metafield_uuid is null then 0
    when a.value_type = 2 and txt.metafield_uuid is not null then 1
    when a.value_type = 3 and num.metafield_uuid is null then 0
    when a.value_type = 3 and num.metafield_uuid is not null then 1
    when a.value_type = 4 and dt.metafield_uuid is null then 0
    when a.value_type = 4 and dt.metafield_uuid is not null then 1
end mf_is_assigned,
date(a.created_at) metafield_created_at,
'Categories' as domain,
COALESCE(opt_l.id, dt.id, num.id, txt.id) as assignment_id,
COALESCE(opt_l.owner_id, dt.owner_id, num.owner_id, txt.owner_id) as owner_id,
case
    when a.value_type = 1 and date(opt_l.created_at) <> date('1970-01-01') then date(opt_l.created_at)
    when a.value_type = 2 and date(txt.created_at) <> date('1970-01-01') then date(txt.created_at)
    when a.value_type = 3 and date(num.created_at) <> date('1970-01-01') then date(num.created_at)
    when a.value_type = 4 and date(dt.created_at) <> date('1970-01-01') then date(dt.created_at)
end as assignment_date,
GREATEST(
    a.sys_audit_updated_on,
    opt_l.sys_audit_updated_on,
    dt.sys_audit_updated_on,
    num.sys_audit_updated_on,
    txt.sys_audit_updated_on,
    msi.sys_audit_updated_on,
    gp.sys_audit_updated_on,
    gmv.gmv_max_sys_audit_updated_on
) AS max_sys_audit_updated_on
from {{ref('product__metafield__categories__event')}} a 
left join {{ref('product__metafield__option_resource_categories__event')}} opt_l 
on opt_l.metafield_uuid = a.uuid
left join {{ref('product__metafield__date_resource_categories__event')}} dt 
on dt.metafield_uuid = a.uuid
left join {{ref('product__metafield__numeric_resource_categories__event')}} num
on num.metafield_uuid = a.uuid -- Esta tabla no fue creada por DPE en Trino por no contener datos
left join {{ref('product__metafield__text_resource_categories__event')}} txt
on txt.metafield_uuid = a.uuid
left join {{ref('moltres__mwp_store_info')}} as msi
on a.store_id = msi.store_id
left join {{ref('operations_grouping_plans')}} gp on gp.plan = msi.plan
left join 
(    SELECT
        store_id,
        round(avg(gmv_usd_monthly),2) AS avg_gmv_usd_last_3m,
        round(avg(orders_monthly)) AS avg_orders_last_3m,
        MAX(sys_audit_updated_on) AS gmv_max_sys_audit_updated_on
    FROM {{ref('company_metrics_gmv_and_segments')}}
    WHERE trunc(datemonth, 'MM') BETWEEN add_months(trunc((SELECT max(datemonth) FROM {{ref('company_metrics_gmv_and_segments')}}), 'MM'),-2)
        AND trunc((SELECT max(datemonth) FROM {{ref('company_metrics_gmv_and_segments')}}), 'MM')
    GROUP BY 1) AS gmv
on a.store_id = gmv.store_id
where 1=1
and a.deleted_at is null
and msi.churned_at is null
and msi.state not in (3,4)
UNION
select 
a.store_id,
msi.domain as store_domain,
msi.state,
msi.country,
msi.current_segment,
gp.grupo plan_name,
case 
    when a.app_id is null then 0
    else 1
end as created_by_app,
gmv.avg_gmv_usd_last_3m as avg_gmv_usd_last_3m,
a.name as name_mf,
a.uuid,
case 
    when a.value_type = 1 then 'Option list'
    when a.value_type = 2 then 'Text'
    when a.value_type = 3 then 'Number'
    when a.value_type = 4 then 'Date'
end as metafield_data_type,
case 
    when date(a.deleted_at) is null or date(a.deleted_at) = date('1970-01-01') then 1
    else 0
end mf_is_active,
case
    when a.value_type = 1 and opt_l.metafield_uuid is null then 0
    when a.value_type = 1 and opt_l.metafield_uuid is not null then 1
    when a.value_type = 2 and txt.metafield_uuid is null then 0
    when a.value_type = 2 and txt.metafield_uuid is not null then 1
    when a.value_type = 3 and num.metafield_uuid is null then 0
    when a.value_type = 3 and num.metafield_uuid is not null then 1
    when a.value_type = 4 and dt.metafield_uuid is null then 0
    when a.value_type = 4 and dt.metafield_uuid is not null then 1
end mf_is_assigned,
date(a.created_at) metafield_created_at,
'Customers' as domain,
COALESCE(opt_l.id, dt.id, num.id, txt.id) as assignment_id,
COALESCE(opt_l.owner_id, dt.owner_id, num.owner_id, txt.owner_id) as owner_id,
case
    when a.value_type = 1 and date(opt_l.created_at) <> date('1970-01-01') then date(opt_l.created_at)
    when a.value_type = 2 and date(txt.created_at) <> date('1970-01-01') then date(txt.created_at)
    when a.value_type = 3 and date(num.created_at) <> date('1970-01-01') then date(num.created_at)
    when a.value_type = 4 and date(dt.created_at) <> date('1970-01-01') then date(dt.created_at)
end as assignment_date,
GREATEST(
    a.sys_audit_updated_on,
    opt_l.sys_audit_updated_on,
    dt.sys_audit_updated_on,
    num.sys_audit_updated_on,
    txt.sys_audit_updated_on,
    msi.sys_audit_updated_on,
    gp.sys_audit_updated_on,
    gmv.gmv_max_sys_audit_updated_on
) AS max_sys_audit_updated_on
from {{ref('product__metafield__customers__event')}} a 
left join {{ref('product__metafield__option_resource_customers__event')}} opt_l 
on opt_l.metafield_uuid = a.uuid
left join {{ref('product__metafield__date_resource_customers__event')}} dt 
on dt.metafield_uuid = a.uuid
left join {{ref('product__metafield__numeric_resource_customers__event')}} num
on num.metafield_uuid = a.uuid
left join {{ref('product__metafield__text_resource_customers__event')}} txt
on txt.metafield_uuid = a.uuid
left join {{ref('moltres__mwp_store_info')}} as msi
on a.store_id = msi.store_id
left join {{ref('operations_grouping_plans')}} gp on gp.plan = msi.plan
left join 
(    SELECT
        store_id,
        round(avg(gmv_usd_monthly),2) AS avg_gmv_usd_last_3m,
        round(avg(orders_monthly)) AS avg_orders_last_3m,
        MAX(sys_audit_updated_on) AS gmv_max_sys_audit_updated_on
    FROM {{ref('company_metrics_gmv_and_segments')}}
    WHERE trunc(datemonth, 'MM') BETWEEN add_months(trunc((SELECT max(datemonth) FROM {{ref('company_metrics_gmv_and_segments')}}), 'MM'),-2)
        AND trunc((SELECT max(datemonth) FROM {{ref('company_metrics_gmv_and_segments')}}), 'MM')
    GROUP BY 1) AS gmv
on a.store_id = gmv.store_id
where 1=1
and a.deleted_at is null
and msi.churned_at is null
and msi.state not in (3,4)
