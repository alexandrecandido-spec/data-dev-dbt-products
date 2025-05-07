WITH
utm_issues AS (
    SELECT
        *
    FROM {{ ref('third_party__github_marketing_attribution') }} as mkt_git
    WHERE mkt_git.input_title like '%PARTNER_FRAUD%'
)

SELECT
    id,
    input_number,
    input_title,
    CASE WHEN TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*partner_code\\*\\*:'), 2),'\\*\\*partner_id\\*\\*:'), 1)), '\\s*-\\s*$', '')) = 'nan' THEN NULL
        ELSE TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*partner_code\\*\\*:'), 2),'\\*\\*partner_id\\*\\*:'), 1)), '\\s*-\\s*$', '')) END AS partner_code,
    CAST(TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*partner_id\\*\\*:'), 2),'\\*\\*fraude\\*\\*:'), 1)), '\\s*-\\s*$', '')) AS INTEGER) AS partner_id,
    CAST(TRIM(element_at(split(body, '\\*\\*fraude\\*\\*:'), 2)) AS INTEGER) AS fraude,
    user_create,
    state,
    assignee,
    comments,
    created_at,
    updated_at,
    closed_at,
    sys_audit_extracted_on,
    sys_audit_created_on,
    sys_audit_updated_on,
    sys_audit_created_by, 
    sys_audit_updated_by
FROM utm_issues