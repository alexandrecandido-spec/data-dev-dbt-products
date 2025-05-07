{{ config(
  materialized='table',
  unique_key=['id'],
  on_schema_change='fail',
  tags=["marketing", "attribution", "daily-4:30"]
) }}

SELECT
    git_referrer.id,
    git_referrer.input_number,
    git_referrer.input_title,
    git_referrer.referrer,
    git_referrer.team,
    git_referrer.subteam,
    git_referrer.user_create,
    git_referrer.state,
    git_referrer.assignee,
    git_referrer.comments,
    git_referrer.created_at,
    git_referrer.updated_at,
    git_referrer.closed_at,
    git_referrer.sys_audit_extracted_on,
    git_referrer.sys_audit_created_on,
    git_referrer.sys_audit_updated_on,
    git_referrer.sys_audit_created_by, 
    git_referrer.sys_audit_updated_by
FROM {{ ref('_int_referrer_github_mkt_attribution') }} git_referrer
-- Only consider open records for attribution model; ignore closed ones
WHERE git_referrer.state = 'open'	