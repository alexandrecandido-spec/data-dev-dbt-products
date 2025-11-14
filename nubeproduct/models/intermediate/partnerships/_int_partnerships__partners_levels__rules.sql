WITH level_rules AS (
    SELECT 
        'BR' AS country_code,
        'Member' AS level,
        0 AS raw_rank,
        0 AS min_active_paying_stores,
        0 AS min_new_payments_last_quarter,
        0 AS min_new_payments_last_365d

    UNION ALL

    SELECT 
        'BR', 
        'Starter', 
        1,
        1,  -- min_active_paying_stores
        0,  -- min_new_payments_last_quarter
        0   -- min_new_payments_last_365d

    UNION ALL

    SELECT 
        'BR', 
        'Silver', 
        2,
        3,  -- min_active_paying_stores
        0,  -- min_new_payments_last_quarter
        1   -- min_new_payments_last_365d

    UNION ALL

    SELECT 
        'BR', 
        'Gold', 
        3,
        10, -- min_active_paying_stores
        1,  -- min_new_payments_last_quarter
        0   -- min_new_payments_last_365d

    UNION ALL

    SELECT 
        'BR', 
        'Platinum', 
        4,
        25, -- min_active_paying_stores
        3,  -- min_new_payments_last_quarter
        0   -- min_new_payments_last_365d
)
SELECT * FROM level_rules;