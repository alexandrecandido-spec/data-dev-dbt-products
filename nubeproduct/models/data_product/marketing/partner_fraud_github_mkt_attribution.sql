{{ config(
  materialized='table',
  unique_key=['id'],
  on_schema_change='fail',
  tags=["marketing", "attribution", "daily-4:30am"]
) }}

SELECT
    git_fraud.id,
    git_fraud.input_number,
    git_fraud.input_title,
    git_fraud.partner_code,
    git_fraud.partner_id,
    git_fraud.fraude,
    git_fraud.user_create,
    git_fraud.state,
    git_fraud.assignee,
    git_fraud.comments,
    git_fraud.created_at,
    git_fraud.updated_at,
    git_fraud.closed_at,
    git_fraud.sys_audit_extracted_on,
    git_fraud.sys_audit_created_on,
    git_fraud.sys_audit_updated_on,
    git_fraud.sys_audit_created_by, 
    git_fraud.sys_audit_updated_by
FROM {{ ref('_int_partner_fraud_github_mkt_attribution') }} git_fraud
-- Only consider open records for merchant fraud filter in the attribution model; ignore closed ones
WHERE git_fraud.state = 'open'	