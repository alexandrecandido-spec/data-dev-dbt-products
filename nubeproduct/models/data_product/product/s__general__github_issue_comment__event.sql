{{ tier_by_prefix() }}
{{ 
  config(
    tags=['daily-9am'],
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['id'],
    on_schema_change='fail',
    post_hook=["
    DELETE FROM {{ this }}
    WHERE EXISTS (
      SELECT 1
      FROM {{ ref('product__general__github_issue_label__link') }} d
      WHERE d.sys_audit_is_deleted = 1
        AND d.repo_name   = {{ this }}.repo_name
        AND d.issue_number = {{ this }}.issue_number
    );
    ",
      "
      DELETE FROM {{ this }}
      WHERE EXISTS (
        SELECT 1
        FROM {{ ref('product__general__github_problem_label__link') }} d
        WHERE d.sys_audit_is_deleted = 1
          AND d.repo_name   = {{ this }}.repo_name
          AND d.issue_number = {{ this }}.issue_number
    );
      "]
  ) 
}}

WITH src AS (
  SELECT * FROM {{ ref('_int__product__general__github_issues_and_problems_comments_union') }}
  WHERE COALESCE(sys_audit_is_deleted, 0) != 1
),
pre AS (
  SELECT
    lower(repo_name) as repo_name,
    id,
    node_id,
    number as issue_number,
    user_login as author,
    body,
    url,
    html_url,
    created_at as github_created_at,
    updated_at as github_updated_at,
    CASE 
      WHEN regexp_replace(regexp_replace(trim(regexp_replace(body, '\\s+', '')), '^[^a-zA-Z0-9\\+]+', ''), '\\s+', '') rlike '^\\+1.*'
      THEN true ELSE false
    END as is_relevant
  FROM src
),
existing_data AS (
  {{ get_existing_data(this, ['id','sys_audit_created_on','sys_audit_created_by']) }}
)

SELECT
  repo_name, pre.id, issue_number, node_id,
  body, author, url, html_url,
  github_created_at, github_updated_at,
  is_relevant,
  COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on, 
  COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by, 
  current_timestamp AS sys_audit_updated_on, 
  'data-dev-dbt-products' AS sys_audit_updated_by
FROM pre
LEFT JOIN existing_data e
  ON pre.id = e.id
{% if is_incremental() %}
WHERE github_updated_at > (
  SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP('1900-01-01 00:00:00')) - INTERVAL 24 HOURS
  FROM {{ this }}
)
{% endif %}