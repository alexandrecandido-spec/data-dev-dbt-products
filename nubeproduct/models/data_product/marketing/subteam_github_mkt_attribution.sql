{{ config(
  materialized='table',
  unique_key=['id'],
  on_schema_change='fail',
  tags=["marketing", "attribution", "daily-4:30"]
) }}

SELECT
    git_sub.id,
    git_sub.input_number,
    git_sub.input_title,
    git_sub.utm_source,
    git_sub.utm_medium,
    git_sub.utm_campaign,
    git_sub.utm_content,
    git_sub.team,
    git_sub.subteam,
    git_sub.user_create,
    git_sub.state,
    git_sub.assignee,
    git_sub.comments,
    git_sub.created_at,
    git_sub.updated_at,
    git_sub.closed_at,
    git_sub.sys_audit_extracted_on,
    git_sub.sys_audit_created_on,
    git_sub.sys_audit_updated_on,
    git_sub.sys_audit_created_by, 
    git_sub.sys_audit_updated_by
FROM {{ ref('_int_subteam_github_mkt_attribution') }} git_sub
-- Only consider open records for attribution model; ignore closed ones
WHERE git_sub.state = 'open'