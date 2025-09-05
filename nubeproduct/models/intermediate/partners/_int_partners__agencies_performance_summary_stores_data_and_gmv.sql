WITH date_spine AS -- Create a table with the date spine for the snapshot date
(
    SELECT DISTINCT 
        first_day_of_week AS snapshot_date
    FROM {{ ref('dim_calendar') }}
    WHERE date_id BETWEEN '2023-01-01' AND CURRENT_DATE()
),
stores_gmv AS  -- Create a table with the gmv metrics for each partner considering the snapshot date
(
    SELECT 
        store_id,
        DS.snapshot_date,
        SUM(CASE WHEN order_date <= DS.snapshot_date THEN gmv_usd_daily ELSE 0 END) AS all_time_gmv,
        SUM(CASE WHEN 
                DATE_TRUNC('MONTH', order_date) = DATE_TRUNC('MONTH', DS.snapshot_date)
                AND order_date <= DS.snapshot_date
            THEN gmv_usd_daily 
            ELSE 0 
        END) AS gmv_usd_current_month,
        SUM(CASE WHEN 
                DATE_TRUNC('MONTH', order_date) = DATE_TRUNC('MONTH', DS.snapshot_date)
                AND order_date <= DS.snapshot_date
            THEN gmv_local_currency_daily 
            ELSE 0 
        END) AS gmv_local_currency_current_month,
        SUM(CASE WHEN DATE_TRUNC('MONTH', order_date) = DATE_TRUNC('MONTH', ADD_MONTHS(DS.snapshot_date, -1)) THEN gmv_usd_daily ELSE 0 END) AS gmv_usd_previous_month,
        SUM(CASE WHEN DATE_TRUNC('MONTH', order_date) = DATE_TRUNC('MONTH', ADD_MONTHS(DS.snapshot_date, -1)) THEN gmv_local_currency_daily ELSE 0 END) AS gmv_local_currency_previous_month,
        SUM(CASE WHEN DATE_TRUNC('QUARTER', order_date) = DATE_TRUNC('QUARTER', ADD_MONTHS(DS.snapshot_date, -3)) THEN gmv_usd_daily ELSE 0 END) AS gmv_usd_last_quarter,
        SUM(CASE WHEN DATE_TRUNC('QUARTER', order_date) = DATE_TRUNC('QUARTER', ADD_MONTHS(DS.snapshot_date, -3)) THEN gmv_local_currency_daily ELSE 0 END) AS gmv_local_currency_last_quarter,
        SUM(CASE WHEN DATE_TRUNC('YEAR', order_date) = DATE_TRUNC('YEAR', ADD_MONTHS(DS.snapshot_date, -12)) THEN gmv_usd_daily ELSE 0 END) AS gmv_usd_last_year,
        SUM(CASE WHEN DATE_TRUNC('YEAR', order_date) = DATE_TRUNC('YEAR', ADD_MONTHS(DS.snapshot_date, -12)) THEN gmv_local_currency_daily ELSE 0 END) AS gmv_local_currency_last_year,
        SUM(CASE WHEN order_date >= DATE_SUB(DS.snapshot_date, 30) THEN gmv_usd_daily ELSE 0 END) AS gmv_usd_last_30d,
        SUM(CASE WHEN order_date >= DATE_SUB(DS.snapshot_date, 30) THEN gmv_local_currency_daily ELSE 0 END) AS gmv_local_currency_last_30d,
        SUM(CASE WHEN order_date >= DATE_SUB(DS.snapshot_date, 90) THEN gmv_usd_daily ELSE 0 END) AS gmv_usd_last_90d,
        SUM(CASE WHEN order_date >= DATE_SUB(DS.snapshot_date, 90) THEN gmv_local_currency_daily ELSE 0 END) AS gmv_local_currency_last_90d,
        SUM(CASE WHEN order_date >= DATE_SUB(DS.snapshot_date, 180) THEN gmv_usd_daily ELSE 0 END) AS gmv_usd_last_180d,    
        SUM(CASE WHEN order_date >= DATE_SUB(DS.snapshot_date, 180) THEN gmv_local_currency_daily ELSE 0 END) AS gmv_local_currency_last_180d,
        SUM(CASE WHEN order_date >= DATE_SUB(DS.snapshot_date, 365) THEN gmv_usd_daily ELSE 0 END) AS gmv_usd_last_365d,
        SUM(CASE WHEN order_date >= DATE_SUB(DS.snapshot_date, 365) THEN gmv_local_currency_daily ELSE 0 END) AS gmv_local_currency_last_365d
    FROM {{ ref('partners_agencies_stores_gmv_orders_daily') }}
    CROSS JOIN date_spine AS DS
    WHERE order_date <= DS.snapshot_date
    GROUP BY 
        store_id,
        DS.snapshot_date
),
agencies_stores AS -- Create a table with the stores depending on partners
(
    SELECT 
        store_id,
        created_at,
        first_payment_flg,
        first_seller_at,
        first_payment,
        churned_at,
        partner_id,
        partner_code,
        partner_created_at,
        partner_country_code,
        DS.snapshot_date
    FROM {{ ref('partners_agencies_affiliates_stores')}}
    CROSS JOIN date_spine AS DS
    WHERE partnership_type = 'store_development'
        AND DATE(created_at) <= DS.snapshot_date
),
contracts AS    -- Create a table with the historicalcontracts for each store
(
    SELECT
        C.contract_id,
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
        AS.store_id,
        AS.created_at,
        AS.first_payment_flg,
        AS.first_seller_at,
        AS.first_payment,
        AS.churned_at,
        AS.partner_id,
        AS.partner_code,
        AS.partner_created_at,
        AS.partner_country_code,
        AS.snapshot_date,
        C.plan_group,
        SG.all_time_gmv,
        SG.gmv_usd_current_month,
        SG.gmv_local_currency_current_month,
        SG.gmv_usd_previous_month,
        SG.gmv_local_currency_previous_month,
        SG.gmv_usd_last_quarter,
        SG.gmv_local_currency_last_quarter,
        SG.gmv_usd_last_year,
        SG.gmv_local_currency_last_year,
        SG.gmv_usd_last_30d,
        SG.gmv_local_currency_last_30d,
        SG.gmv_usd_last_90d,
        SG.gmv_local_currency_last_90d,
        SG.gmv_usd_last_180d,    
        SG.gmv_local_currency_last_180d,
        SG.gmv_usd_last_365d,
        SG.gmv_local_currency_last_365d
    FROM agencies_stores AS AS
    LEFT JOIN contracts AS C    
        ON AS.store_id = C.store_id
            AND AS.snapshot_date BETWEEN C.start_date AND C.end_date
    LEFT JOIN stores_gmv AS SG
        ON AS.store_id = SG.store_id
            AND AS.snapshot_date = SG.snapshot_date
)
SELECT 
    CR.* EXCEPT(RN)
FROM contracts_ranks AS CR
WHERE CR.RN = 1