{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['dealbreaker_id', 'sys_audit_created_on'],
    tags = ['daily-9am']
) }}

WITH existing AS (
    {{ get_existing_data(this, [
        'dealbreaker_id',
        'repo_name',
        'issue_number',
        'store_id',
        'impact',
        'dealbreaker_start_date',
        'dealbreaker_close_date',
        'high_start_date',
        'high_close_date',
        'sys_audit_created_on',
        'sys_audit_created_by',
        'sys_audit_updated_on',
        'sys_audit_updated_by',
        'valid_from',
        'valid_to',
        'is_current',
        'is_valid'
    ]) }}
),

latest_existing AS (
    SELECT * EXCEPT(row_number)
    FROM (
        SELECT *,
            ROW_NUMBER() OVER (
                PARTITION BY dealbreaker_id
                ORDER BY sys_audit_created_on DESC
            ) AS row_number
        FROM existing
    )
    WHERE row_number = 1
),

new_versions AS (
    SELECT
        d.dealbreaker_id,
        d.repo_name,
        d.issue_number,
        d.store_id,
        d.impact,
        d.dealbreaker_start_date,
        d.dealbreaker_close_date,
        d.high_start_date,
        d.high_close_date,
        current_timestamp AS valid_from,
        NULL AS valid_to,
        TRUE AS is_current,
        TRUE AS is_valid,
        current_timestamp AS sys_audit_created_on,
        'data-dev-dbt-products' AS sys_audit_created_by,
        current_timestamp AS sys_audit_updated_on,
        'data-dev-dbt-products' AS sys_audit_updated_by
    FROM {{ ref('product_hubspot_dealbreakers') }} d
    LEFT JOIN latest_existing e
      ON d.dealbreaker_id = e.dealbreaker_id
WHERE e.dealbreaker_id IS NULL

-- repo_name
   OR d.repo_name <> e.repo_name
   OR d.repo_name IS NULL AND e.repo_name IS NOT NULL
   OR d.repo_name IS NOT NULL AND e.repo_name IS NULL

-- issue_number
   OR d.issue_number <> e.issue_number
   OR d.issue_number IS NULL AND e.issue_number IS NOT NULL
   OR d.issue_number IS NOT NULL AND e.issue_number IS NULL

-- store_id
   OR d.store_id <> e.store_id
   OR d.store_id IS NULL AND e.store_id IS NOT NULL
   OR d.store_id IS NOT NULL AND e.store_id IS NULL

-- impact
   OR d.impact <> e.impact
   OR d.impact IS NULL AND e.impact IS NOT NULL
   OR d.impact IS NOT NULL AND e.impact IS NULL

-- dealbreaker_start_date
   OR d.dealbreaker_start_date <> e.dealbreaker_start_date
   OR d.dealbreaker_start_date IS NULL AND e.dealbreaker_start_date IS NOT NULL
   OR d.dealbreaker_start_date IS NOT NULL AND e.dealbreaker_start_date IS NULL

-- dealbreaker_close_date
   OR d.dealbreaker_close_date <> e.dealbreaker_close_date
   OR d.dealbreaker_close_date IS NULL AND e.dealbreaker_close_date IS NOT NULL
   OR d.dealbreaker_close_date IS NOT NULL AND e.dealbreaker_close_date IS NULL

-- high_start_date
   OR d.high_start_date <> e.high_start_date
   OR d.high_start_date IS NULL AND e.high_start_date IS NOT NULL
   OR d.high_start_date IS NOT NULL AND e.high_start_date IS NULL

-- high_close_date
   OR d.high_close_date <> e.high_close_date
   OR d.high_close_date IS NULL AND e.high_close_date IS NOT NULL
   OR d.high_close_date IS NOT NULL AND e.high_close_date IS NULL
),

close_previous_versions AS (
    SELECT
        e.dealbreaker_id,
        e.repo_name,
        e.issue_number,
        e.store_id,
        e.impact,
        e.dealbreaker_start_date,
        e.dealbreaker_close_date,
        e.high_start_date,
        e.high_close_date,
        e.valid_from,
        current_timestamp AS valid_to,
        FALSE AS is_current,
        e.is_valid,
        e.sys_audit_created_on,
        e.sys_audit_created_by,
        current_timestamp AS sys_audit_updated_on,
        'data-dev-dbt-products' AS sys_audit_updated_by
    FROM latest_existing e
    INNER JOIN new_versions n
      ON e.dealbreaker_id = n.dealbreaker_id
)

SELECT * FROM new_versions
UNION ALL
SELECT * FROM close_previous_versions
