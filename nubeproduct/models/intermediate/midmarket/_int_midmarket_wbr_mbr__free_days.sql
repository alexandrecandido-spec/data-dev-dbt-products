-- Owner: Guille De Felice

-- Weekly free days
SELECT 
    mc.store_id,
    'weekly' AS periodicity,
    SUM(
        CASE
            WHEN mc.start_date > date_trunc('week', current_date) THEN DATEDIFF(mc.end_date, mc.start_date)
            WHEN date_trunc('week', current_date) BETWEEN mc.start_date AND mc.end_date THEN DATEDIFF(mc.end_date, date_trunc('week', current_date))
        END
    ) AS free_days
FROM {{ source('int_moltres','mwp_contracts') }} mc 
INNER JOIN {{ ref('midmarket_success_stores') }} sid 
    ON mc.store_id = sid.store_id  
WHERE 
    mc.type IN ('free','free-days')
    AND mc.end_date > date_trunc('week', current_date)
    AND mc.deleted_at IS NULL
GROUP BY 1

UNION ALL

-- Monthly free days
SELECT 
    mc.store_id,
    'monthly' AS periodicity,
    SUM(
        CASE
            WHEN mc.start_date > date_trunc('month', current_date) - interval '1 day' THEN DATEDIFF(mc.end_date, mc.start_date)
            WHEN date_trunc('month', current_date) - interval '1 day' BETWEEN mc.start_date AND mc.end_date THEN DATEDIFF(mc.end_date, date_trunc('month', current_date) - interval '1 day')
        END
    ) AS free_days
FROM {{ source('int_moltres','mwp_contracts') }} mc 
INNER JOIN {{ ref('midmarket_success_stores') }} sid 
    ON mc.store_id = sid.store_id  
WHERE 
    mc.type IN ('free','free-days')
    AND mc.end_date > date_trunc('month', current_date) - interval '1 day'
    AND mc.deleted_at IS NULL
GROUP BY 1