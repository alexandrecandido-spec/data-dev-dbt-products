{{ tier_by_prefix() }}
{{ 
  config(
    tags=['daily-9am'],
    materialized='table',
    unique_key=['id','repo_name','issue_number'],
    on_schema_change='fail'
  ) 
}}

WITH src AS (
  SELECT * FROM {{ ref('_int__product__general__github_issues_and_problems_union') }}
  WHERE COALESCE(sys_audit_is_deleted, 0) != 1
  AND is_latest_by_repo_and_number = TRUE
),
pre AS (
  SELECT
    lower(repo_name) as repo_name,
    milestone_id as id,
    issue_number,
    milestone_node_id as node_id,
    milestone_html_url as html_url,
    milestone_title as title,
    milestone_description as description,
    milestone_state as state,
    milestone_created_at as github_created_at,
    milestone_updated_at as github_updated_at,
    milestone_due_on as github_due_on,
    milestone_closed_at as github_closed_at
  FROM src
  WHERE milestone_id IS NOT NULL
),
pre_dedup AS (
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY repo_name, id, issue_number
      ORDER BY COALESCE(github_updated_at, github_created_at) DESC,
               node_id DESC
    ) AS _rn
  FROM pre
  QUALIFY _rn = 1
),
existing_data AS (
  {{ get_existing_data(this, ['id','repo_name','issue_number','sys_audit_created_on','sys_audit_created_by']) }}
)

SELECT
  pre_dedup.repo_name, pre_dedup.id, pre_dedup.issue_number, node_id, html_url, title, description, state,
  github_created_at, github_updated_at, github_due_on, github_closed_at,
  COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
  COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
  current_timestamp AS sys_audit_updated_on,
  'data-dev-dbt-products' AS sys_audit_updated_by
FROM pre_dedup
LEFT JOIN existing_data e
  ON pre_dedup.repo_name = e.repo_name
  AND pre_dedup.issue_number = e.issue_number
  AND pre_dedup.id = e.id
