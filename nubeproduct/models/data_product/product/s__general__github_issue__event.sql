{{ tier_by_prefix() }}
{{ 
  config(
    tags=['daily-9am'],
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['id'],
    on_schema_change='fail',
    post_hook=["DELETE FROM {{ this }} WHERE id in (SELECT id FROM {{ ref('product__general__github_issue_label__link') }} WHERE sys_audit_is_deleted = 1) ",
        "DELETE FROM {{ this }} WHERE id in (SELECT id FROM {{ ref('product__general__github_problem_label__link') }} WHERE sys_audit_is_deleted = 1)"]
  ) 
}}

WITH base AS (
  SELECT *
  FROM {{ ref('_int__product__general__github_issues_and_problems_union') }}
  WHERE COALESCE(sys_audit_is_deleted, 0) != 1
),
labels AS (
  SELECT 
    id,
    concat_ws(', ', collect_set(labels_name)) AS labels_name
  FROM base
  WHERE is_latest_by_repo_and_number = TRUE
  GROUP BY id
),
ranked AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (
            PARTITION BY repo_name, issue_number 
            ORDER BY updated_at DESC
        ) AS rn
    FROM base
),
existing_data AS (
  {{ get_existing_data(this, ['id','sys_audit_created_on','sys_audit_created_by']) }}
)

SELECT 
    lower(repo_name) as repo_name,
    s.id,
    s.issue_number,
    node_id,
    created_at as github_created_at,
    updated_at as github_updated_at,
    closed_at as github_closed_at,
    l.labels_name,
    CASE WHEN lower(l.labels_name) rlike '(not a problem|not an issue)' THEN true ELSE false END as is_test,
    title, body,
    user_login as author,
    state, state_reason, comments, comments_url,
    locked, active_lock_reason, url, events_url, html_url,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM ranked s
LEFT JOIN labels l
  ON s.id = l.id
LEFT JOIN existing_data e
  ON s.id = e.id
WHERE rn = 1
{% if is_incremental() %}
  AND updated_at >= (SELECT COALESCE(MAX(sys_audit_updated_on), '1970-01-01') - INTERVAL 1 HOURS FROM {{ this }})
{% endif %}
