{{ tier_by_prefix() }}
{{ 
  config(
    tags=['daily-9am'],
    materialized='table',
    unique_key=['id'],
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
joined AS (
  SELECT
    i.repo_name as repo_name,
    i.issue_number as issue_number,
    i.labels_name as name,
    i.labels_description as description,
    i.labels_color as color,
    i.created_at as github_created_at,
    e.id as event_id,
    e.created_at as event_created_at
  FROM issues i
  LEFT JOIN events e
    ON  i.issue_number = e.number
    AND i.repo_name = e.repo_name
    AND i.labels_name = e.label_name
),
ranked AS (
  SELECT
    COALESCE(event_id, cast((unix_timestamp() * 10000) as bigint) + row_number() OVER (ORDER BY issue_number)) as id,
    lower(repo_name) as repo_name,
    issue_number,
    name,
    description,
    color,
    github_created_at,
    row_number() OVER (PARTITION BY issue_number, repo_name, name ORDER BY event_created_at DESC NULLS LAST) as rnk,
    event_created_at
  FROM joined
  WHERE name IS NOT NULL AND name <> 'nan'
),
existing_data AS (
  {{ get_existing_data(this, ['id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT
  ranked.id, repo_name, issue_number, name, description, color, github_created_at,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM ranked
LEFT JOIN existing_data e
  ON ranked.id = e.id
WHERE rnk = 1
