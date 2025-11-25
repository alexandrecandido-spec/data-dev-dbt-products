{{ config(
  materialized = 'table',
  unique_key = ['dealbreaker_id', 'valid_from'],
  on_schema_change = 'fail',
  tags = ['daily-9am']
) }}

-- s__general__dealbreakers_process_valid__event

SELECT
    repo_name,
    issue_number,
    dealbreaker_source,
    dealbreaker_id,
    author,
    is_relevant,
    valid_from,
    store_id,
    impact,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by

FROM {{ ref('_int__product__dealbreakers_process_comment_like_input') }}
