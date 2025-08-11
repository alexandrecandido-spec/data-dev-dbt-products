-- Owner: Guille De Felice

{{
    config(
        materialized='incremental',
        unique_key=['date_from', 'periodicity', 'store_id'],
        incremental_strategy='append',
        on_schema_change='fail',
        tags = ['operations', 'weekly-monday-9am-monthly-1st-12pm']
    )
}}

WITH weekly AS (
    SELECT 
        CAST(date_trunc('week', d.snapshot_date) AS DATE) as date_from,
        d.store_id,
        'weekly' AS periodicity,
        SUM(d.qtd_sessions) AS sessions
    FROM {{ source("dp_uplift", "distributions") }} d
    INNER JOIN {{ source("dp_moltres", "mwp_store_info") }} s
        ON d.store_id = s.id
    WHERE
        d.snapshot_date < date_trunc('week', current_date)
        AND (s.churned_at IS NULL OR date_trunc('week', d.snapshot_date) < date_trunc('week', s.churned_at))
    GROUP BY 1, 2, 3
),

monthly AS (
    SELECT 
        CAST(date_trunc('month', d.snapshot_date) AS DATE) as date_from,
        d.store_id,
        'monthly' AS periodicity,
        SUM(d.qtd_sessions) AS sessions
    FROM {{ source("dp_uplift", "distributions") }} d
    INNER JOIN {{ source("dp_moltres", "mwp_store_info") }} s
        ON d.store_id = s.id
    WHERE
        d.snapshot_date < date_trunc('month', current_date)
        AND (s.churned_at IS NULL OR date_trunc('month', d.snapshot_date) < date_trunc('month', s.churned_at))
    GROUP BY 1, 2, 3
),

all_sessions AS (
    SELECT 
        *,
        LAG(sessions) OVER (
            PARTITION BY store_id, periodicity
            ORDER BY date_from
        ) AS previous_sessions
    FROM (
        SELECT * FROM weekly
        UNION ALL
        SELECT * FROM monthly
    ) all_data
),

final_query AS (
    SELECT 
        *
    FROM 
        all_sessions ls
    {% if is_incremental() %}
    WHERE
        (ls.periodicity = 'weekly' AND ls.date_from > (
            SELECT max(date_from) 
            FROM {{ this }} 
            WHERE periodicity = 'weekly'
            ))
        OR 
        (ls.periodicity = 'monthly' AND ls.date_from > (
            SELECT max(date_from) 
            FROM {{ this }} 
            WHERE periodicity = 'monthly'
            ))
    {% endif %}
)

SELECT 
    *,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by
FROM 
    final_query
WHERE 
    sessions > 0
    OR COALESCE(previous_sessions, 0) > 0