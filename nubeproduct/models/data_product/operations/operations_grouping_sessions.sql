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
        date_trunc('week', d.snapshot_date) AS date_from,
        d.store_id,
        'weekly' AS periodicity,
        SUM(d.qtd_sessions) AS sessions
    FROM {{ source("dp_uplift", "distributions") }} d
    INNER JOIN {{ source("dp_moltres", "mwp_store_info") }} s
        ON d.store_id = s.id
    WHERE
        d.snapshot_date < date_trunc('week', current_date)
        AND (s.churned_at IS NULL OR date_trunc('week', d.snapshot_date) < date_trunc('week', s.churned_at))
        {% if is_incremental() %}
            AND date_trunc('week', d.snapshot_date) > (
                SELECT max(date_from)
                FROM {{ this }}
                WHERE periodicity = 'weekly'
            )
        {% endif %}
    GROUP BY 1, 2, 3
),

monthly AS (
    SELECT 
        date_trunc('month', d.snapshot_date) AS date_from,
        d.store_id,
        'monthly' AS periodicity,
        SUM(d.qtd_sessions) AS sessions
    FROM {{ source("dp_uplift", "distributions") }} d
    INNER JOIN {{ source("dp_moltres", "mwp_store_info") }} s
        ON d.store_id = s.id
    WHERE
        d.snapshot_date < date_trunc('month', current_date)
        AND (s.churned_at IS NULL OR date_trunc('month', d.snapshot_date) < date_trunc('month', s.churned_at))
        {% if is_incremental() %}
            AND date_trunc('month', d.snapshot_date) > (
                SELECT max(date_from)
                FROM {{ this }}
                WHERE periodicity = 'monthly'
            )
        {% endif %}
    GROUP BY 1, 2, 3
),

final_query AS (
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
    OR COALESCE(previous_sessions, 0) > 0;