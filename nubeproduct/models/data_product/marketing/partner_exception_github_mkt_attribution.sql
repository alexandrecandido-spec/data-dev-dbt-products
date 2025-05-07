{{ config(
  materialized='table',
  unique_key=['id'],
  on_schema_change='fail',
  tags=["marketing", "attribution", "daily-4:30"]
) }}

SELECT
    git_partner_exceptions.id,
    git_partner_exceptions.input_number,
    git_partner_exceptions.input_title,
    git_partner_exceptions.partner_code,
    git_partner_exceptions.team,
    git_partner_exceptions.subteam,
    git_partner_exceptions.user_create,
    git_partner_exceptions.state,
    git_partner_exceptions.assignee,
    git_partner_exceptions.comments,
    git_partner_exceptions.created_at,
    git_partner_exceptions.updated_at,
    git_partner_exceptions.closed_at,
    git_partner_exceptions.sys_audit_extracted_on,
    git_partner_exceptions.sys_audit_created_on,
    git_partner_exceptions.sys_audit_updated_on,
    git_partner_exceptions.sys_audit_created_by, 
    git_partner_exceptions.sys_audit_updated_by
FROM {{ ref('_int_partner_exceptions_github_mkt_attribution') }} git_partner_exceptions
-- Only consider open records for attribution model; ignore closed ones
WHERE git_partner_exceptions.state = 'open'	