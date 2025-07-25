WITH base_comments AS (
  SELECT DISTINCT 
    ic.repo_name,
    ic.issue_number,
    s.impact,
    iss.store_id,
    coalesce(ic.github_created_at, i.github_created_at) AS comment_date,
    ic.sys_audit_updated_at
  FROM {{ source('int_github_data', 'issue_comment') }} ic
  INNER JOIN {{ source('int_github_data', 'issue_store') }} iss 
    ON ic.repo_name = iss.repo_name 
    AND ic.issue_number = iss.issue_number 
    AND ic.id = iss.comment_id
  INNER JOIN {{ source('int_github_data', 'issue') }} i 
    ON ic.repo_name = i.repo_name 
    AND ic.issue_number = i.issue_number
  LEFT JOIN {{ source('int_github_data', 'store_impact') }} s 
    ON ic.repo_name = s.repo_name 
    AND ic.issue_number = s.issue_number 
    AND ic.id = s.comment_id
),
latest_comments AS (
  SELECT 
    repo_name,
    issue_number,
    store_id,
    comment_date,
    impact,
    sys_audit_updated_at,
    ROW_NUMBER() OVER (PARTITION BY repo_name, issue_number, store_id ORDER BY comment_date DESC) AS rn -- aca no entiendo porque hace el max con github_created_at, pensaria que deberia hacerse con comment_date.
  FROM base_comments
)
SELECT 
  repo_name,
  issue_number,
  store_id,
  impact,
  CAST(comment_date AS DATE) AS comment_date,
  sys_audit_updated_at
FROM latest_comments
WHERE rn = 1