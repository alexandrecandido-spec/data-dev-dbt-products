-- depends_on: {{ ref('finance_store_gmv_and_segments') }}

{{
    config(
        materialized='incremental',
        unique_key=['repo_name', 'issue_number', 'wip_label'],
        on_schema_change='fail',
        tags=["product","daily-4am"]
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
        FROM {{ ref('finance_store_gmv_and_segments') }}
        WHERE datemonth >= date_add(month, -4, current_date) -- For BigQuery
        -- WHERE datemonth >= DATEADD(month, -4, CURRENT_DATE()) -- For Snowflake
        GROUP BY 1
    ) AS gmv
        ON issue_store.store_id = gmv.store_id
)

SELECT
    *
FROM data
WHERE rank = 1