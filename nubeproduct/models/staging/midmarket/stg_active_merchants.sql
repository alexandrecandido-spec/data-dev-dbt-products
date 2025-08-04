{{
    config(
        materialized = 'incremental',
        unique_key = ['store_id', 'date'],
        on_schema_change = 'fail',
        tags = ['weekly-monday-10am']
    )
}}

WITH base AS (
    SELECT *,
           last_day(date) AS last_day_of_month,
           current_date() AS today
    FROM {{ source('stg_active_merchants', 'active_merchants') }}

    {% if is_incremental() %}
      -- Garante reprocessamento do mês atual e anterior
      WHERE date >= date_trunc('month', current_date() - interval '1 month')
    {% endif %}
),

marcadas AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY store_id, year, month
               ORDER BY date DESC
           ) AS rn_desc
    FROM base
),

filtradas AS (
    SELECT *
    FROM marcadas
    WHERE 
        -- Mês fechado: pega o último dia do mês
        (date = last_day_of_month)
        OR
        -- Mês atual: pega a data mais recente disponível
        (year = year(today) AND month = month(today) AND rn_desc = 1)
),

existing_data AS (
    {{ get_existing_data(this, ['store_id', 'date', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT
    f.store_id,
    f.store_country,
    f.store_id_plan_country,
    DATE_TRUNC('month', f.date) AS date,  -- primeiro dia do mês, como chave
    f.year,
    f.month,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM filtradas f
LEFT JOIN existing_data e
  ON f.store_id = e.store_id AND DATE_TRUNC('month', f.date) = e.date