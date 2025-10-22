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
    GREATEST(
        COALESCE(d.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP)),
        COALESCE(da.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP)),
        COALESCE(dc.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP)),
        COALESCE(c.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP))
    ) AS sys_audit_updated_on

FROM {{ ref('product__general__hubspot_dealbreaker__event') }} d
JOIN {{ ref('product__general__hubspot_dealbreaker_current__snapshot_daily') }} da
    ON d.dealbreaker_id = da.dealbreaker_id
JOIN {{ ref('product__general__hubspot_dealbreaker_company__link') }} dc
    ON d.dealbreaker_id = dc.dealbreaker_id
JOIN {{ ref('product__general__hubspot_company__event') }} c
    ON dc.company_id = c.company_id
