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
        churned_at,
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
        ROW_NUMBER() OVER(PARTITION BY ASS.store_id, ASS.snapshot_date ORDER BY C.contract_id DESC) AS RN,
        AS.partner_id,
        ASS.store_id,
        ASS.first_payment,
        ASS.created_at,
        ASS.tag_acquired_by,
        ASS.new_payment,
        ASS.snapshot_date,
        ASS.partner_country_code,
        ASS.churned_at,
        C.plan_group
    FROM agencies_stores AS ASS
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
    BM.partner_country_code,
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
    AND BM.first_payment IS NOT NULL
    AND BM.first_payment BETWEEN DATE_SUB(BM.snapshot_date, 365) AND BM.snapshot_date THEN 1 ELSE 0 END) 
    AS new_payments_last_365d
FROM temp_base AS BM
GROUP BY BM.partner_id, BM.snapshot_date, BM.partner_country_code
),
matched_rules AS 
(
SELECT 
    BM.*,
    LR.level AS partner_level_raw,
    LR.raw_rank AS raw_rank
    /*
    CASE 
        WHEN partner_country_code = 'BR'
        THEN       
            CASE 
                WHEN active_paying_stores >= 25 
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
            END
    ELSE 'Rules undefined for this country'
    END AS partner_level_test
    */
FROM base_metrics AS BM
LEFT JOIN {{ ref('int_partnerships__partners_levels__rules') }} AS LR
    ON LR.country_code = BM.partner_country_code
     AND BM.active_paying_stores >= LR.min_active_paying_stores
     AND BM.new_payments_last_quarter >= LR.min_new_payments_last_quarter
     AND BM.new_payments_last_365d >= LR.min_new_payments_last_365d
)
raw_levels AS 
(
    SELECT
        partner_id,
        partner_country_code,
        snapshot_date,
        active_paying_stores,
        new_payments_last_quarter,
        new_payments_last_365d,
        COALESCE(
          MAX_BY(partner_level_raw, raw_rank),
          'Member'
        ) AS partner_level_raw,
        COALESCE(
          MAX(raw_rank),
          0
        ) AS raw_rank
    FROM matched_rules
    GROUP BY
        partner_id,
        partner_country_code,
        snapshot_date,
        active_paying_stores,
        new_payments_last_quarter,
        new_payments_last_365d
)
SELECT * FROM raw_levels;