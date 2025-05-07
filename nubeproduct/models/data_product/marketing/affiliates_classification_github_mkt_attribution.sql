{{ config(
  materialized='table',
  unique_key=['id'],
  on_schema_change='fail',
  tags=["marketing", "attribution", "daily-4:30am"]
) }}

SELECT
    git_affiliates.id,
    git_affiliates.input_number,
    git_affiliates.input_title,
    git_affiliates.affiliate_code,
    git_affiliates.classification,
    git_affiliates.country,
    git_affiliates.tier,
    git_affiliates.fit,
    git_affiliates.main_platform,
    git_affiliates.user_create,
    git_affiliates.state,
    git_affiliates.assignee,
    git_affiliates.comments,
    git_affiliates.created_at,
    git_affiliates.updated_at,
    git_affiliates.closed_at,
    git_affiliates.sys_audit_extracted_on,
    git_affiliates.sys_audit_created_on,
    git_affiliates.sys_audit_updated_on,
    git_affiliates.sys_audit_created_by, 
    git_affiliates.sys_audit_updated_by
FROM {{ ref('_int_affiliates_classification_github_mkt_attribution') }} git_affiliates
-- Only consider open records when classifying affiliates; ignore closed ones.
WHERE git_affiliates.state = 'open'