{{
    config(
        tags = ['product', 'daily-8am'],
        materialized='incremental',
        unique_key='record_id',
        on_schema_change='fail'
    )
}}

SELECT
	properties_hs_object_id as record_id,
    archived as is_archived,
    properties_hs_createdate as record_created_at,
    properties_hs_lastmodifieddate as record_updated_at,
    case
        when properties_type = 'Issue' then 'issues'
        when properties_type = 'Problem' then 'problems'
    end as repo_name,
    cast(properties_github_id as integer) as issue_number,
    case
        when properties_criticality = 'High Priority' then 'high'
        when properties_criticality = 'Dealbreaker' then 'dealbreaker'
    end as impact,
    properties_start_date as dealbreaker_start_date,
    properties_close_date as dealbreaker_close_date,
    properties_start_highpriority_date as high_start_date,
    properties_close_highpriority_date as high_close_date,
    properties_hs_pipeline as pipeline,
    properties_hs_pipeline_stage as pipeline_stage,
    properties_github_title as github_title,
    properties_github_status as github_status,
    properties_hubspot_team_id as owner_team_id,
    properties_hubspot_owner_id as owner_id,
    properties_hs_object_source_id as source_id,
    properties_hs_created_by_user_id as created_by_user_id,
    properties_hs_updated_by_user_id as updated_by_user_id,
    properties_hs_object_source_user_id as source_user_id,
    properties_hs_user_ids_of_all_owners as all_owners_ids,
    properties_hubspot_owner_assigneddate as owner_assigned_at,
    properties_hs_all_assigned_business_unit_ids as brands,
    properties_close_date as record_closed_at,
	current_timestamp AS sys_audit_created_on,
	'data-dev-dbt-products' AS sys_audit_created_by,
	current_timestamp AS sys_audit_updated_on,
	'data-dev-dbt-products' AS sys_audit_updated_by
FROM
	{{ source('stg_hubspot', 'dealbreakers') }} d

{% if is_incremental() %}

WHERE d._airbyte_extracted_at >= 
(select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} )

{% endif %}