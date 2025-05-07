{{ config(
  materialized='table',
  unique_key=['id'],
  on_schema_change='fail',
  tags=["marketing", "attribution", "daily-4:30"]
) }}

SELECT
    git_utm.id,
    git_utm.input_number,
    git_utm.input_title,
    git_utm.utm_source,
    git_utm.utm_medium,
    git_utm.utm_campaign,
    git_utm.utm_content,
    git_utm.team,
    git_utm.subteam,
    git_utm.user_create,
    git_utm.state,
    git_utm.assignee,
    git_utm.comments,
    git_utm.created_at,
    git_utm.updated_at,
    git_utm.closed_at,
    git_utm.sys_audit_extracted_on,
    git_utm.sys_audit_created_on,
    git_utm.sys_audit_updated_on,
    git_utm.sys_audit_created_by, 
    git_utm.sys_audit_updated_by
FROM {{ ref('_int_utm_github_mkt_attribution') }} git_utm 
-- Only consider open records for attribution model; ignore closed ones
WHERE git_utm.state = 'open'