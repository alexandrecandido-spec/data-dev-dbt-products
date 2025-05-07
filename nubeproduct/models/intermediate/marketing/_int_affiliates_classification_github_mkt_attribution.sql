WITH
utm_issues AS (
    SELECT
        *
    FROM {{ ref('third_party__github_marketing_attribution') }} as mkt_git
    WHERE mkt_git.input_title like '%AFFILIATE_LIST%'
)

SELECT
    id,
    input_number,
    input_title,
    CASE WHEN TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*affiliate_code\\*\\*:'), 2),'\\*\\*classification\\*\\*:'), 1)), '\\s*-\\s*$', '')) = 'nan' THEN NULL
        ELSE TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*affiliate_code\\*\\*:'), 2),'\\*\\*classification\\*\\*:'), 1)), '\\s*-\\s*$', '')) END AS affiliate_code,
    CASE WHEN TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*classification\\*\\*:'), 2),'\\*\\*country\\*\\*:'), 1)), '\\s*-\\s*$', '')) = 'nan' THEN NULL
        ELSE TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*classification\\*\\*:'), 2),'\\*\\*country\\*\\*:'), 1)), '\\s*-\\s*$', '')) END AS classification,
    CASE WHEN TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*country\\*\\*:'), 2),'\\*\\*tier\\*\\*:'), 1)), '\\s*-\\s*$', '')) = 'nan' THEN NULL 
        ELSE TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*country\\*\\*:'), 2),'\\*\\*tier\\*\\*:'), 1)), '\\s*-\\s*$', '')) END AS country,
    CASE WHEN TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*tier\\*\\*:'), 2),'\\*\\*fit\\*\\*:'), 1)), '\\s*-\\s*$', '')) = 'nan' THEN NULL 
        ELSE TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*tier\\*\\*:'), 2),'\\*\\*fit\\*\\*:'), 1)), '\\s*-\\s*$', '')) END AS tier,
    CASE WHEN TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*fit\\*\\*:'), 2),'\\*\\*main_platform\\*\\*:'), 1)), '\\s*-\\s*$', '')) = 'nan' THEN NULL 
        ELSE TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*fit\\*\\*:'), 2),'\\*\\*main_platform\\*\\*:'), 1)), '\\s*-\\s*$', '')) END AS fit,
    CASE WHEN TRIM(REGEXP_EXTRACT(body, '(?:\\*\\*main_platform\\*\\*|main_platform):\\s*([^\\n\\r]+)', 1)) = 'nan' THEN NULL
        ELSE TRIM(REGEXP_EXTRACT(body, '(?:\\*\\*main_platform\\*\\*|main_platform):\\s*([^\\n\\r]+)', 1)) END AS main_platform,
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