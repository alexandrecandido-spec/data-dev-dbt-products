WITH date_spine AS -- Create a table with the date spine for the snapshot date
(
    SELECT 
        MIN(first_day_of_month) AS snapshot_date,
        year_id,
        quarter_id
    FROM {{ ref('dim_calendar') }}
    WHERE first_day_of_month BETWEEN '2023-01-01' AND CURRENT_DATE()
    GROUP BY year_id, quarter_id
),
agencies_stores AS
(
    SELECT 
        partner_id,
        store_id,
        first_payment,
        created_at,
        tag_acquired_by,
        new_payment,
        partner_country_code,
        DS.snapshot_date
    FROM {{ ref('_int_partnerships__partners_stores__table_merchant_domain')}}
    CROSS JOIN date_spine AS DS
    WHERE partnership_type = 'store_development'
        AND DATE(created_at) <= DS.snapshot_date
),
contracts AS    -- Create a table with the historicalcontracts for each store
(
    SELECT
        C.id AS contract_id,
        C.store_id,
        C.plan_id,
        C.type,
        C.start_date,
        C.end_date,
        OGP.grupo AS plan_group
    FROM {{ ref('moltres__contracts') }} AS C
    LEFT JOIN {{ ref('operations_grouping_plans') }} AS OGP
        ON C.plan_id = OGP.plan
    WHERE C.start_date >= '2021-01-01'
), 
contracts_ranks AS
(
    SELECT
        ROW_NUMBER() OVER(PARTITION BY AS.store_id, AS.snapshot_date ORDER BY C.contract_id DESC) AS RN,
        AS.partner_id,
        AS.store_id,
        AS.first_payment,
        AS.created_at,
        AS.tag_acquired_by,
        AS.new_payment,
        AS.snapshot_date,
        AS.partner_country_code,
        C.plan_group
    FROM agencies_stores AS AS
    LEFT JOIN contracts AS C    
        ON AS.store_id = C.store_id
            AND AS.snapshot_date BETWEEN C.start_date AND C.end_date
),
temp_base AS    
(
    SELECT    
        *
    FROM contracts_ranks AS CR
    WHERE RN = 1
),
base_metrics AS
(
    SELECT 
    BM.partner_id,
    BM.snapshot_date,
    SUM(CASE WHEN 
        BM.first_payment IS NOT NULL 
        AND BM.first_payment <= BM.snapshot_date 
        AND (BM.churned_at IS NULL OR BM.churned_at > BM.snapshot_date)
        AND BM.plan_group != 'freemium'  
    THEN 1 ELSE 0 END)
    AS active_paying_stores,
    SUM(CASE WHEN 
    BM.tag_acquired_by = 'Partner'
    AND BM.first_payment IS NOT NULL
    AND DATE_TRUNC('QUARTER', BM.first_payment) = DATE_TRUNC('QUARTER', ADD_MONTHS(BM.snapshot_date, -3))
    THEN 1 ELSE 0 END) AS new_payments_last_quarter,
    SUM(CASE WHEN 
    BM.tag_acquired_by = 'Partner'
    ANDBM.first_payment IS NOT NULL
    AND BM.first_payment BETWEEN DATE_SUB(BM.snapshot_date, 365) AND BM.snapshot_date THEN 1 ELSE 0 END) 
    AS new_payments_last_365d
FROM temp_base AS BM
)
SELECT 
    BM.*,
    CASE 
        WHEN partner_country_code = 'BR'
        THEN       
            CASE 
                WHEN active_paying_stores >= 25 
                    AND new_payments_last_quarter >= 3
                    AND LAG(active_paying_stores, 1) OVER (PARTITION BY partner_id ORDER BY snapshot_date) >= 10
                    AND LAG(new_payments_last_quarter, 1) OVER (PARTITION BY partner_id ORDER BY snapshot_date) >= 1
                    AND new_payments_last_quarter >= 3
                THEN 'Platinum'
                WHEN active_paying_stores >= 10 
                    AND new_payments_last_quarter >= 1
                THEN 'Gold'
                WHEN active_paying_stores >= 3 
                    AND new_payments_last_365d >= 1
                THEN 'Silver'
                WHEN active_paying_stores >= 1 
                THEN 'Starter'
                ELSE 'Member'
    ELSE 'Rules undefined for this country'
    END AS partner_level
FROM base_metrics AS BM