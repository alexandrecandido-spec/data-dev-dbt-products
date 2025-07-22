{{
    config(
        materialized='incremental',
        unique_key=['repo_name', 'issue_number', 'wip_label'],
		incremental_strategy='merge',
        on_schema_change='fail',
        tags=["product","daily-10am"]
    )
}}

with labels as (
			select 
				iel.repo_name,
				iel.issue_number,
                iel.content as wip_label,
				min(github_created_at) as first_label_creation_date,
				max(github_created_at) as last_label_creation_date,
				max(sys_audit_updated_at) as max_sys_audit_updated_at,
				min(sys_audit_updated_at) as min_sys_audit_updated_at,
				count(*) as q_registros
			from {{ source('stg_github_data', 'issue_events') }} iel
			where iel.event = 'labeled'
				and iel.content in ('1 - WIP - Identificando problema', '2 - WIP - Entendiendo solucion', '3 - WIP - Ejecutando solucion', '4 - WIP - Monitoreando solucion')
			group by 1,2,3
		), unlabels as(
			select 
				iel.repo_name,
				iel.issue_number,
                iel.content as wip_label,
				max(github_created_at) as last_unlabel_date,
				max(sys_audit_updated_at) as max_sys_audit_updated_at,
				count(*) as q_registros
			from {{ source('stg_github_data', 'issue_events') }} iel
			where iel.event = 'unlabeled'
				and iel.content in ('1 - WIP - Identificando problema', '2 - WIP - Entendiendo solucion', '3 - WIP - Ejecutando solucion', '4 - WIP - Monitoreando solucion')
			group by 1,2,3
)
	select la.repo_name, 
		la.issue_number, 
        la.wip_label,
		cast(la.first_label_creation_date as date) as wip_last_updated, 
		cast(ul.last_unlabel_date as date) as wip_last_deleted,
		CAST(to_date(wip_last_updated, 'yyyyMMdd') AS STRING) AS year_month_day_code,
    	current_timestamp AS sys_audit_created_on,
    	'data-dev-dbt-products' AS sys_audit_created_by,
    	current_timestamp AS sys_audit_updated_on,
    	'data-dev-dbt-products' AS sys_audit_updated_by
	from labels la 
	left join unlabels ul on la.repo_name = ul.repo_name 
		and ul.issue_number = la.issue_number
		and ul.last_unlabel_date > la.last_label_creation_date
        and ul.wip_label = la.wip_label
	    {% if is_incremental() %}
    WHERE
        la.max_sys_audit_updated_at >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} )
		or la.min_sys_audit_updated_at >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} )
		or ul.max_sys_audit_updated_at >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} )
    {% endif %}