{{ tier_by_prefix() }}
{{ 
  config(
    tags=['daily-9am'],
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['id'],
    on_schema_change='fail'
  ) 
}}

WITH src AS (
  SELECT * FROM {{ ref('_int__product__general__github_issues_and_problems_events_union') }}
  WHERE COALESCE(sys_audit_is_deleted, 0) != 1
),
mapped AS (
  SELECT
    id,
    number as issue_number,
    lower(repo_name) as repo_name,
    event,
    created_at as github_created_at,
    actor_login as actor,
    CASE
      WHEN event = 'reopened' THEN state_reason
      WHEN event IN ('unassigned','assigned') THEN assignee_login
      WHEN event IN ('milestoned','demilestoned') THEN milestone_title
      WHEN event IN ('labeled','unlabeled') THEN label_name
      ELSE NULL
    END as content
  FROM src
),
existing_data AS (
  {{ get_existing_data(this, ['id','sys_audit_created_on','sys_audit_created_by']) }}
)

SELECT
  mapped.id, 
  issue_number, 
  repo_name, 
  event, 
  github_created_at, 
  actor, 
  content,
  COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
  COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
  current_timestamp AS sys_audit_updated_on,
  'data-dev-dbt-products' AS sys_audit_updated_by
FROM mapped
LEFT JOIN existing_data e
  ON mapped.id = e.id
{% if is_incremental() %}
WHERE github_created_at > (
  SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP('1900-01-01 00:00:00')) - INTERVAL 1 HOURS
  FROM {{ this }}
)
{% endif %}
