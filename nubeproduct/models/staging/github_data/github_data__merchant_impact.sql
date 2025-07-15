-- depends_on: {{ ref('company_metrics_gmv_and_segments') }} a

{{
    config(
        materialized='table',
        unique_key=['repo_name', 'issue_number', 'store_id'],
        on_schema_change='fail',
        tags=["product","daily-8am"]
    )
}}

WITH data AS (
    SELECT
        issue_store.store_id,
        issue_store.repo_name,
        issue_store.issue_number,
        i.state AS issue_state,
        store_impact.impact AS store_impact,
        gmv.sum_gmv,
        gmv.avg_gmv_usd,
        ROW_NUMBER() OVER (PARTITION BY issue_store.store_id, issue_store.repo_name, issue_store.issue_number ORDER BY store_impact.impact) AS rank
    FROM {{ source('stg_github_data', 'issue_store') }} AS issue_store
    LEFT JOIN {{ source('stg_github_data', 'issue') }} AS i
        ON i.issue_number = issue_store.issue_number AND i.repo_name = issue_store.repo_name
    LEFT JOIN {{ source('stg_github_data', 'store_impact') }} AS store_impact
        ON store_impact.comment_id = issue_store.comment_id
    LEFT JOIN (
        SELECT
            store_id,
            SUM(gmv_usd_monthly) AS sum_gmv,
            AVG(gmv_usd_monthly) AS avg_gmv_usd
        FROM {{ ref('company_metrics_gmv_and_segments') }}
        WHERE datemonth >= date_add(month, -4, current_date) -- For BigQuery
        -- WHERE datemonth >= DATEADD(month, -4, CURRENT_DATE()) -- For Snowflake
        GROUP BY 1
    ) AS gmv
        ON issue_store.store_id = gmv.store_id
)

SELECT
    store_id,
    repo_name,
    issue_number,
    issue_state,
    store_impact,
    sum_gmv,
    avg_gmv_usd,
    CAST(to_date(current_timestamp, 'yyyyMMdd') AS STRING) AS year_month_day_code,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM data
WHERE rank = 1
