SELECT
    p.id AS payment_id,
    p.store_id,
    op.grupo as plan,
    c.start_date AS from_date,
    c.end_date AS to_date,
    date(p.paid_at) as paid_at,
    p.price as amount_value,
    si.churned_at,
    si.country AS country_code,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by,
    CAST(date_format(paid_at, 'yyyyMMdd') AS INT) AS year_month_day_code
FROM
    {{ source('int_moltres', 'mwp_payment_stores') }} ps
LEFT JOIN {{ ref('operations_grouping_plans') }} AS op ON ps.plan_id = op.plan
LEFT JOIN
    {{ source('int_moltres', 'mwp_payments') }} p ON ps.payment_id = p.id
LEFT JOIN (
    SELECT 
        payment_store_id, 
        MIN(c.start_date) AS start_date, 
        MAX(c.end_date) AS end_date
    FROM {{ source('int_moltres', 'mwp_contracts') }} c
    WHERE c.deleted_at IS NULL
    GROUP BY payment_store_id
) c ON c.payment_store_id = ps.id
LEFT JOIN
    {{ source('int_moltres', 'mwp_store_info') }} si ON si.id = p.store_id
WHERE
    si.state <> 4
    AND p.state = 2
    AND p.paid_at BETWEEN '2021-01-01' AND '2025-01-01'
    AND p.id IS NOT NULL