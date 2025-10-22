{{
    config(
        tags = ['product', 'daily-8am'],
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='dealbreaker_id',
        on_schema_change='fail'
    )
}}

WITH existing_data AS (
    {{ get_existing_data(this, ['dealbreaker_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT
    cast(d.properties_hs_object_id as bigint) as dealbreaker_id, -- lo casteo porque estaba como decimal
    d.archived as is_archived, -- este campo es estático en esta tabla porque en la tabla de origen son todos false, cuando deja de serlo desaparece, pero la estrategia de incrementalidad de airbyte es merge y no elimina registros
    d.properties_hs_createdate as record_created_at,
    d.properties_hs_lastmodifieddate as record_updated_at,
    case
        when d.properties_type = 'Issue' then 'issues'
        when d.properties_type = 'Problem' then 'problems'
    end as repo_name,
    cast(d.properties_github_id as bigint) as issue_number,
    case
        when d.properties_criticality = 'High Priority' then 'high'
        when d.properties_criticality = 'Dealbreaker' then 'dealbreaker'
    end as impact,
    d.properties_start_date as dealbreaker_start_date,
    d.properties_close_date as dealbreaker_close_date,
    d.properties_start_highpriority_date as high_start_date,
    d.properties_close_highpriority_date as high_close_date,
    d.properties_hs_pipeline as pipeline,
    d.properties_hs_pipeline_stage as pipeline_stage,
    d.properties_github_title as github_title,
    d.properties_github_status as github_status,
    d.properties_hubspot_team_id as owner_team_id,
    d.properties_hubspot_owner_id as owner_id,
    d.properties_hs_object_source_id as source_id, -- no se castea porque toma valores no numéricos cuando es cargado por un user_id
    cast(d.properties_hs_created_by_user_id as bigint) as created_by_user_id,
    cast(d.properties_hs_updated_by_user_id as bigint) as updated_by_user_id,
    cast(d.properties_hs_object_source_user_id as bigint) as source_user_id,
    d.properties_hs_user_ids_of_all_owners as all_owners_ids, -- no sabemos qué valores puede tomar
    d.properties_hubspot_owner_assigneddate as owner_assigned_at,
    d.properties_hs_all_assigned_business_unit_ids as brands,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by

FROM {{ source('stg_hubspot', 'dealbreakers') }} d
LEFT JOIN existing_data e ON cast(d.properties_hs_object_id as bigint) = e.dealbreaker_id

{% if is_incremental() %}
WHERE d._airbyte_extracted_at >= (
    SELECT COALESCE(MAX(sys_audit_updated_on), '1900-01-01') FROM {{ this }}
)
{% endif %}
