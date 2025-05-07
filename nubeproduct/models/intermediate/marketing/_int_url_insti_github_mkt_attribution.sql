WITH
utm_issues AS (
    SELECT
        *
    FROM {{ ref('third_party__github_marketing_attribution') }} as mkt_git
    WHERE mkt_git.input_title like '%URL%'
)

SELECT
    id,
    input_number,
    input_title,
    CASE WHEN TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*url\\*\\*:'), 2),'\\*\\*landing_page_domain\\*\\*:'), 1)), '\\s*-\\s*$', '')) = 'nan' THEN NULL
        ELSE TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*url\\*\\*:'), 2),'\\*\\*landing_page_domain\\*\\*:'), 1)), '\\s*-\\s*$', '')) END AS url,
    CASE WHEN TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*landing_page_domain\\*\\*:'), 2),'\\*\\*landing_page_path\\*\\*:'), 1)), '\\s*-\\s*$', '')) = 'nan' THEN NULL
        ELSE TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*landing_page_domain\\*\\*:'), 2),'\\*\\*landing_page_path\\*\\*:'), 1)), '\\s*-\\s*$', '')) END AS landing_page_domain,
    CASE WHEN TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*landing_page_path\\*\\*:'), 2),'\\*\\*team\\*\\*:'), 1)), '\\s*-\\s*$', '')) = 'nan' THEN NULL 
        ELSE TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*landing_page_path\\*\\*:'), 2),'\\*\\*team\\*\\*:'), 1)), '\\s*-\\s*$', '')) END AS landing_page_path,
    CASE WHEN TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*team\\*\\*:'), 2),'\\*\\*subteam\\*\\*:'), 1)), '\\s*-\\s*$', '')) = 'nan' THEN NULL 
        ELSE INITCAP(TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*team\\*\\*:'), 2),'\\*\\*subteam\\*\\*:'), 1)), '\\s*-\\s*$', ''))) END AS team,
    CASE WHEN TRIM(REGEXP_EXTRACT(body, '(?:\\*\\*subteam\\*\\*|subteam):\\s*([^\\n\\r]+)', 1)) = 'nan' THEN NULL
        ELSE INITCAP(TRIM(REGEXP_EXTRACT(body, '(?:\\*\\*subteam\\*\\*|subteam):\\s*([^\\n\\r]+)', 1))) END AS subteam,
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