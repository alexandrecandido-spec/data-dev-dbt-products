{{ tier_by_prefix() }}
{{ 
  config(
    tags=['daily-9am'],
    materialized='table',
    unique_key=['repo_name','issue_number','login'],
    on_schema_change='fail'
  ) 
}}

WITH issues AS (
  SELECT * FROM {{ ref('_int__product__general__github_issues_and_problems_union') }}
  WHERE COALESCE(sys_audit_is_deleted, 0) != 1
    AND is_latest_by_repo_and_number = TRUE
),
events AS (
  SELECT * FROM {{ ref('_int__product__general__github_issues_and_problems_events_union') }}
  WHERE COALESCE(sys_audit_is_deleted, 0) != 1
),
merged AS (
  SELECT
    i.repo_name,
    i.issue_number,
    i.assignee_login as login,
    i.assignee_url as url,
    i.assignee_type as type,
    e.id as event_id,
    e.created_at as event_created_at
  FROM issues i
  LEFT JOIN events e
    ON i.repo_name = e.repo_name
   AND i.issue_number = e.number
   AND i.assignee_login = e.assignee_login
),
ranked AS (
  SELECT
    lower(repo_name) as repo_name,
    issue_number,
    login,
    url,
    type,
    COALESCE(event_id, cast((unix_timestamp()*10000) as bigint) + row_number() OVER (ORDER BY issue_number)) as id,
    row_number() OVER (PARTITION BY repo_name, issue_number, login ORDER BY event_created_at DESC NULLS LAST) as rnk,
    event_created_at
  FROM merged
  WHERE type IS NOT NULL AND type <> 'nan'
),
existing_data AS (
  {{ get_existing_data(this, ['repo_name','issue_number','login', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT
  ranked.repo_name, ranked.id, ranked.issue_number, ranked.login, ranked.url, ranked.type, 
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM ranked
LEFT JOIN existing_data e
  ON ranked.repo_name = e.repo_name
  AND ranked.issue_number = e.issue_number
  AND ranked.login = e.login
WHERE rnk = 1
