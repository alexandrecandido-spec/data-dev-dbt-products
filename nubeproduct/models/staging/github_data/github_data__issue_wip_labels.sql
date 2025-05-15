{{
    config(
        materialized='incremental',
        unique_key=['repo_name', 'issue_number', 'wip_label'],
        on_schema_change='fail',
        tags=["product","daily-4am"]
    )
}}

with labels as (
			select 
				iel.repo_name,
				iel.issue_number,
                iel.content as wip_label,
				min(github_created_at) as first_label_creation_date,
				max(github_created_at) as last_label_creation_date,
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
		cast(ul.last_unlabel_date as date) as wip_last_deleted
	from labels la 
	left join unlabels ul on la.repo_name = ul.repo_name 
		and ul.issue_number = la.issue_number
		and ul.last_unlabel_date > la.last_label_creation_date
        and ul.wip_label = la.wip_label