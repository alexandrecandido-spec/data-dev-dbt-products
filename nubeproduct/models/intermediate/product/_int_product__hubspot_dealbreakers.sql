SELECT
	d.dealbreaker_id,
    d.is_archived,
    d.record_created_at,
    d.record_updated_at,
    d.repo_name,
    d.issue_number,
    c.store_id,
    c.company_id,
    d.impact,
    d.dealbreaker_start_date,
    d.dealbreaker_close_date,
    d.high_start_date,
    d.high_close_date,
    d.pipeline,
    d.pipeline_stage,
    d.github_title,
    d.github_status,
    d.owner_team_id,
    d.owner_id,
    d.source_id,
    d.created_by_user_id,
    d.updated_by_user_id,
    d.source_user_id,
    d.all_owners_ids,
    d.owner_assigned_at,
    d.brands,
    d.record_closed_at,
    GREATEST(
        COALESCE(d.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP)),
        COALESCE(dca.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP)),
        COALESCE(c.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP))
    ) AS sys_audit_updated_on
FROM {{ ref('hubspot__dealbreakers') }} d
LEFT JOIN {{ ref('hubspot__dealbreakers_companies_associations') }} dca
    ON d.dealbreaker_id = dca.dealbreaker_id
LEFT JOIN {{ ref('hubspot__companies') }} c
    ON dca.company_id = c.company_id