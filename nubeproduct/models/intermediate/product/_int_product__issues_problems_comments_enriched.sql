
SELECT
    ic.repo_name,
    ic.issue_number,
    ic.comment_id,
    ic.author,
    ic.is_relevant,
    ic.comment_date,
    ist.store_id,
    si.impact,
    GREATEST(
        COALESCE(ic.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP)),
        COALESCE(ist.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP)),
        COALESCE(si.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP))
    ) AS sys_audit_updated_on
FROM {{ ref('github_data__issue_comment') }} ic
LEFT JOIN {{ ref('github_data__issue_store') }} ist
    ON ic.repo_name = ist.repo_name
    AND ic.issue_number = ist.issue_number
    AND ic.comment_id = ist.comment_id
LEFT JOIN {{ ref('github_data__store_impact') }} si
    ON si.repo_name = ic.repo_name
    AND si.issue_number = ic.issue_number
    AND ic.comment_id = si.comment_id