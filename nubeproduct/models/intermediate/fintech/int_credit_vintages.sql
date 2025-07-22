-- Credit vintages analysis: tracks payment behavior by contract vintage cohorts
WITH base_contracts AS (
    SELECT 
        hub_contract_id,
        custom_status,
        finished_at,
        DATE(DATE_TRUNC('month', first_installment_at))AS first_installment_month,
        DATE(first_installment_at) - INTERVAL '1' MONTH AS start_period,
        -- Create vintage curve up to max 15 months
        MAX(DATE(first_installment_at)) OVER (
            PARTITION BY DATE_TRUNC('month', first_installment_at)
        ) + INTERVAL '15' MONTH AS end_period
    FROM {{ ref('fintech_contracts') }}
),

date_series AS (
    SELECT DATE(d) AS calendar_month
    FROM (SELECT explode(sequence(to_date('2023-01-01'), current_date, interval 1 month)) AS d)
),
monthly_contract_periods AS (
    SELECT 
        c.hub_contract_id,
        c.custom_status,
        c.finished_at,
        c.first_installment_month,
        ds.calendar_month,
        -- Calculate original due date maintaining the day of month from start_period
        to_date(
            format_string('%s-%02d', date_format(ds.calendar_month, 'yyyy-MM'), day(c.start_period)), 
            'yyyy-MM-dd'
        ) AS original_due_date,
        ROW_NUMBER() OVER (
            PARTITION BY c.hub_contract_id 
            ORDER BY ds.calendar_month ASC
        ) AS rank_installments,
        -- For renegotiated contracts, use finished_at; otherwise use current date
        CASE 
            WHEN c.custom_status = 'renegotiated' THEN c.finished_at 
            ELSE current_date 
        END AS finished_date_for_renegs
    FROM base_contracts c
    INNER JOIN date_series ds 
        ON ds.calendar_month BETWEEN c.start_period AND c.end_period
),

paid_installments AS (
    SELECT
        CAST(i.hub_contract_id AS INTEGER) AS hub_contract_id,
        DATE(i.paid_at) AS paid_at,
        i.paid_amount / 100 AS u_paid,
        i.principal_amount / 100 AS principal_paid
    FROM {{ source('stg_nuvem_credito', 'installments') }} i
    WHERE i.status = 'paid'
),

contracts_with_debt_amounts AS (
    SELECT
        mcp.*,
        COALESCE(
            SUM(oi.original_amount) OVER (
                PARTITION BY mcp.hub_contract_id 
                ORDER BY mcp.original_due_date
            ), 0
        ) AS original_amount,
        COALESCE(
            SUM(oi.principal_amount) OVER (
                PARTITION BY mcp.hub_contract_id 
                ORDER BY mcp.original_due_date
            ), 0
        ) AS principal_amount
    FROM monthly_contract_periods mcp
    LEFT JOIN {{ ref('nuvem_credito__initial_installments') }} oi 
        ON mcp.hub_contract_id = oi.hub_contract_id
        AND mcp.calendar_month = oi.original_due_month
)

SELECT
    cwda.hub_contract_id,
    cwda.first_installment_month,
    cwda.finished_at,
    cwda.custom_status,
    cwda.calendar_month,
    cwda.original_due_date,
    cwda.rank_installments,
    cwda.original_amount as original_due_amount,
    cwda.principal_amount as principal_due_amount,
    COALESCE(SUM(pi.u_paid), 0) AS paid_amount,
    COALESCE(SUM(pi.principal_paid), 0) AS principal_paid_amount
FROM contracts_with_debt_amounts cwda
LEFT JOIN paid_installments pi
    ON cwda.hub_contract_id = pi.hub_contract_id 
    AND pi.paid_at <= (cwda.original_due_date + INTERVAL '10' DAY) --10 days as grace period
    AND pi.paid_at < cwda.finished_date_for_renegs
GROUP BY
    cwda.hub_contract_id,
    cwda.first_installment_month,
    cwda.finished_at,
    cwda.custom_status,
    cwda.calendar_month,
    cwda.original_due_date,
    cwda.rank_installments,
    cwda.original_amount,
    cwda.principal_amount

