WITH
utm_issues AS (
    SELECT
        *
    FROM {{ ref('third_party__github_marketing_attribution') }} as mkt_git
    WHERE mkt_git.input_title like '%UTM%'
)

SELECT
    id,
    input_number,
    input_title,
    CASE WHEN TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*utm_source\\*\\*:'), 2),'\\*\\*utm_medium\\*\\*:'), 1)), '\\s*-\\s*$', '')) = 'nan' THEN NULL
        ELSE TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*utm_source\\*\\*:'), 2),'\\*\\*utm_medium\\*\\*:'), 1)), '\\s*-\\s*$', '')) END AS utm_source,
    CASE WHEN TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*utm_medium\\*\\*:'), 2),'\\*\\*utm_campaign\\*\\*:'), 1)), '\\s*-\\s*$', '')) = 'nan' THEN NULL
        ELSE TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*utm_medium\\*\\*:'), 2),'\\*\\*utm_campaign\\*\\*:'), 1)), '\\s*-\\s*$', '')) END AS utm_medium,
    CASE WHEN TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*utm_campaign\\*\\*:'), 2),'\\*\\*utm_content\\*\\*:'), 1)), '\\s*-\\s*$', '')) = 'nan' THEN NULL 
        ELSE TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*utm_campaign\\*\\*:'), 2),'\\*\\*utm_content\\*\\*:'), 1)), '\\s*-\\s*$', '')) END AS utm_campaign,
    CASE WHEN TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*utm_content\\*\\*:'), 2),'\\*\\*team\\*\\*:'), 1)), '\\s*-\\s*$', '')) = 'nan' THEN NULL 
        ELSE TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*utm_content\\*\\*:'), 2),'\\*\\*team\\*\\*:'), 1)), '\\s*-\\s*$', '')) END AS utm_content,
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