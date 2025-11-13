{{
  config(
    tags = ['product','daily-9am'],
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['id','labels_name'],
    on_schema_change='fail'
  )
}}

WITH existing_data AS (
  {{ get_existing_data(this, ['id','labels_name','sys_audit_created_on','sys_audit_created_by']) }}
),

raw_source AS (
  SELECT
    url,
    html_url,
    title,
    id,
    node_id,
    user_login,
    state,
    state_reason,
    comments,
    comments_url,
    events_url,
    locked,
    active_lock_reason,
    closed_at,
    created_at,
    updated_at,
    body,
    number AS issue_number,
    'issues' AS repo_name,
    milestone_id,
    milestone_node_id,
    milestone_number,
    milestone_html_url,
    milestone_title,
    milestone_description,
    milestone_state,
    milestone_created_at,
    milestone_updated_at,
    milestone_due_on,
    milestone_closed_at,
    assignee_id,
    assignee_login,
    assignee_url,
    assignee_type,
    labels_id,
    CASE
      WHEN labels_name IS NULL THEN '__no_label__'
      WHEN trim(lower(labels_name)) IN ('', 'nan', 'none', 'null') THEN '__no_label__'
      ELSE labels_name
    END AS labels_name,
    labels_description,
    labels_color,
    sys_audit_extracted_on,                  
    sys_audit_is_deleted,
    sys_audit_deleted_on
  FROM {{ source('stg_third_party','product_github_issues') }}
  {% if is_incremental() %}
    WHERE sys_audit_updated_on >
      (
        SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01 00:00:00') - INTERVAL 124 HOURS
        FROM {{ this }}
      )
  {% endif %}
),

source_dedup AS (
  SELECT *,
  CASE
    WHEN raw_source.sys_audit_extracted_on = MAX(raw_source.sys_audit_extracted_on)
                                  OVER (PARTITION BY raw_source.repo_name, raw_source.issue_number)
    THEN TRUE
    ELSE FALSE
  END AS is_latest_by_repo_and_number
  FROM raw_source
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY id, labels_name
    ORDER BY sys_audit_extracted_on DESC
  ) = 1
)

SELECT
  s.*,
  COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
  COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
  current_timestamp AS sys_audit_updated_on,
  'data-dev-dbt-products' AS sys_audit_updated_by
FROM source_dedup s
LEFT JOIN existing_data e
  ON s.id = e.id
 AND s.labels_name = e.labels_name