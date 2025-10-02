{{
  config(
    materialized = 'table',
    tags = ['finance', 'daily-10am']
  )
}}

SELECT
    c.id AS concept_id,
    c.code AS concept_code,
    c.type,
    CAST(date_format(sys_audit_created_on, 'yyyyMMdd') AS INT) AS year_month_day_code,
    c.updatedat AS updated_at,
    COALESCE(sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ source('stg_billing', 'concept') }} as c
