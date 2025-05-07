{{ config(
  materialized='table',
  unique_key=['id'],
  on_schema_change='fail',
  tags=["marketing", "attribution", "daily-4:30"]
) }}

SELECT
    git_url.id,
    git_url.input_number,
    git_url.input_title,
    git_url.url,
    git_url.landing_page_domain,
    git_url.landing_page_path,
    git_url.team,
    git_url.subteam,
    git_url.user_create,
    git_url.state,
    git_url.assignee,
    git_url.comments,
    git_url.created_at,
    git_url.updated_at,
    git_url.closed_at,
    git_url.sys_audit_extracted_on,
    git_url.sys_audit_created_on,
    git_url.sys_audit_updated_on,
    git_url.sys_audit_created_by, 
    git_url.sys_audit_updated_by
FROM {{ ref('_int_url_insti_github_mkt_attribution') }} git_url
-- Only consider open records for attribution model; ignore closed ones
WHERE git_url.state = 'open'
AND git_url.url IS NOT NULL	