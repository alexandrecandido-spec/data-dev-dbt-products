WITH
issues AS (
    SELECT
    git_mkt.id,
    git_mkt.number AS input_number,
    git_mkt.title AS input_title,
    CASE WHEN git_mkt.title like '%UTM%' THEN 'UTM'
        WHEN git_mkt.title like '%SUBTEAM_MKT%' THEN 'SUBTEAM_MKT'
        WHEN git_mkt.title like '%URL%' THEN 'URL'
        WHEN git_mkt.title like '%PARTNER_CODE%' THEN 'PARTNER_CODE'
        WHEN git_mkt.title like '%PARTNER_FRAUD%' THEN 'PARTNER_FRAUD'
        WHEN git_mkt.title like '%REFERRER%' THEN 'REFERRER'
        WHEN git_mkt.title like '%AFFILIATE_LIST%' THEN 'AFFILIATE_LIST'     
        ELSE 'OTHER' END AS issue_type,
    LOWER(git_mkt.user_login) AS user_create,
    git_mkt.state,
    git_mkt.body,
    git_mkt.assignee,
    git_mkt.comments,
    git_mkt.created_at,
    git_mkt.updated_at,
    git_mkt.closed_at,
    git_mkt.sys_audit_extracted_on,
    COALESCE(git_mkt.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    current_timestamp AS sys_audit_updated_on,
    COALESCE(git_mkt.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by, 
    'data-dev-dbt-products' AS sys_audit_updated_by
    FROM {{source('int_third_party', 'marketing_github_mkt_attribution')}} as git_mkt
)

SELECT
    id,
    input_number,
    input_title,
    issue_type,
    CASE WHEN issue_type IN ('UTM', 'SUBTEAM_MKT') THEN LOWER(TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*utm_source\\*\\*:'), 2),'\\*\\*utm_medium\\*\\*:'), 1)), '\\s*-\\s*$', ''))) END AS utm_source,
    CASE WHEN issue_type IN ('UTM', 'SUBTEAM_MKT') THEN LOWER(TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*utm_medium\\*\\*:'), 2),'\\*\\*utm_campaign\\*\\*:'), 1)), '\\s*-\\s*$', ''))) END AS utm_medium,
    CASE WHEN issue_type IN ('UTM', 'SUBTEAM_MKT') THEN LOWER(TRIM(BOTH '%' FROM TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*utm_campaign\\*\\*:'), 2),'\\*\\*utm_content\\*\\*:'), 1)), '\\s*-\\s*$', '')))) END AS utm_campaign,
    CASE WHEN issue_type IN ('UTM', 'SUBTEAM_MKT') THEN LOWER(TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*utm_content\\*\\*:'), 2),'\\*\\*team\\*\\*:'), 1)), '\\s*-\\s*$', ''))) END AS utm_content,
    CASE WHEN issue_type IN ('URL') THEN LOWER(TRIM(BOTH '%' FROM TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*url\\*\\*:'), 2),'\\*\\*landing_page_domain\\*\\*:'), 1)), '\\s*-\\s*$', '')))) END AS url,
    CASE WHEN issue_type IN ('URL') THEN LOWER(TRIM(BOTH '%' FROM TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*landing_page_domain\\*\\*:'), 2),'\\*\\*landing_page_path\\*\\*:'), 1)), '\\s*-\\s*$', '')))) END AS landing_page_domain,
    CASE WHEN issue_type IN ('URL') THEN LOWER(TRIM(BOTH '%' FROM TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*landing_page_path\\*\\*:'), 2),'\\*\\*team\\*\\*:'), 1)), '\\s*-\\s*$', '')))) END AS landing_page_path,
    CASE WHEN issue_type IN ('REFERRER') THEN LOWER(TRIM(BOTH '%' FROM TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*referrer\\*\\*:'), 2),'\\*\\*team\\*\\*:'), 1)), '\\s*-\\s*$', '')))) END AS referrer,
    CASE WHEN issue_type = 'PARTNER_CODE' THEN TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*partner_code\\*\\*:'), 2),'\\*\\*team\\*\\*:'), 1)), '\\s*-\\s*$', ''))
        WHEN issue_type = 'PARTNER_FRAUD' THEN TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*partner_code\\*\\*:'), 2),'\\*\\*partner_id\\*\\*:'), 1)), '\\s*-\\s*$', '')) END AS partner_code,
    CASE WHEN issue_type = 'PARTNER_FRAUD' THEN CAST(TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*partner_id\\*\\*:'), 2),'\\*\\*fraude\\*\\*:'), 1)), '\\s*-\\s*$', '')) AS INTEGER) END AS partner_id,
    CASE WHEN issue_type = 'PARTNER_FRAUD' THEN CAST(TRIM(element_at(split(body, '\\*\\*fraude\\*\\*:'), 2)) AS INTEGER) END AS fraude,
    CASE WHEN issue_type = 'AFFILIATE_LIST' THEN TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*affiliate_code\\*\\*:'), 2),'\\*\\*classification\\*\\*:'), 1)), '\\s*-\\s*$', '')) END AS affiliate_code,
    CASE WHEN issue_type = 'AFFILIATE_LIST' THEN TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*classification\\*\\*:'), 2),'\\*\\*country\\*\\*:'), 1)), '\\s*-\\s*$', '')) END AS classification,
    CASE WHEN issue_type = 'AFFILIATE_LIST' THEN TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*country\\*\\*:'), 2),'\\*\\*tier\\*\\*:'), 1)), '\\s*-\\s*$', '')) END AS country,
    CASE WHEN issue_type = 'AFFILIATE_LIST' THEN TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*tier\\*\\*:'), 2),'\\*\\*fit\\*\\*:'), 1)), '\\s*-\\s*$', '')) END AS tier,
    CASE WHEN issue_type = 'AFFILIATE_LIST' THEN TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*fit\\*\\*:'), 2),'\\*\\*main_platform\\*\\*:'), 1)), '\\s*-\\s*$', '')) END AS fit,
    CASE WHEN issue_type = 'AFFILIATE_LIST' THEN TRIM(REGEXP_EXTRACT(body, '(?:\\*\\*main_platform\\*\\*|main_platform):\\s*([^\\n\\r]+)', 1)) END AS main_platform,
    CASE WHEN issue_type IN ('UTM', 'SUBTEAM_MKT', 'URL', 'REFERRER', 'PARTNER_CODE') THEN INITCAP(TRIM(REGEXP_REPLACE(TRIM(element_at(split(element_at(split(body, '\\*\\*team\\*\\*:'), 2),'\\*\\*subteam\\*\\*:'), 1)), '\\s*-\\s*$', ''))) END AS team,
    CASE WHEN issue_type IN ('UTM', 'SUBTEAM_MKT', 'URL', 'REFERRER', 'PARTNER_CODE') THEN INITCAP(TRIM(REGEXP_EXTRACT(body, '(?:\\*\\*subteam\\*\\*|subteam):\\s*([^\\n\\r]+)', 1))) END AS subteam,
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
FROM issues