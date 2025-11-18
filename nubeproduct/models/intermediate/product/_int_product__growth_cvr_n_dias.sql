WITH base AS (
    SELECT 
        core.store_id,
        CAST(core.created_at AS DATE) AS date,
        status.first_payment,
        core.country_code AS country,
        core.device,
        DATEDIFF(status.first_payment, core.created_at) AS diff,
        CASE 
            WHEN CAST(core.partner_id AS string) IS NULL THEN FALSE
            ELSE TRUE
        END AS is_affiliate,
        status.is_store_blocked
    FROM {{ ref('_int__attributes__store_core')}} AS core
    LEFT JOIN {{ ref('_int__lifecycle__store_status')}} AS status 
    ON core.store_id = status.store_id
    WHERE 
        CAST(core.created_at AS DATE) >= '2022-01-01' 
),

aux AS (
    SELECT 
        *
    FROM base
    WHERE first_payment IS NOT NULL
),

agg AS (
    SELECT 
        date,
        country,
        device,
        is_affiliate,
        is_store_blocked,
        SUM(CASE WHEN diff <= 7  THEN 1 ELSE 0 END) AS total07,
        SUM(CASE WHEN diff <= 14 THEN 1 ELSE 0 END) AS total14,
        SUM(CASE WHEN diff <= 21 THEN 1 ELSE 0 END) AS total21,
        SUM(CASE WHEN diff <= 28 THEN 1 ELSE 0 END) AS total28,
        SUM(CASE WHEN diff <= 35 THEN 1 ELSE 0 END) AS total35,
        SUM(CASE WHEN diff <= 42 THEN 1 ELSE 0 END) AS total42,
        SUM(CASE WHEN diff <= 49 THEN 1 ELSE 0 END) AS total49,
        SUM(CASE WHEN diff <= 56 THEN 1 ELSE 0 END) AS total56,
        SUM(CASE WHEN diff <= 63 THEN 1 ELSE 0 END) AS total63,
        SUM(CASE WHEN diff <= 70 THEN 1 ELSE 0 END) AS total70,
        SUM(CASE WHEN diff <= 77 THEN 1 ELSE 0 END) AS total77,
        SUM(CASE WHEN diff <= 84 THEN 1 ELSE 0 END) AS total84
    FROM aux
    GROUP BY date, country, device, is_affiliate, is_store_blocked
),

unpivoted AS (
    SELECT 
        date,
        country,
        device,
        is_affiliate,
        is_store_blocked,
        days_agg,
        stores
    FROM agg
    LATERAL VIEW STACK(
        12,                       
        'total07', total07,
        'total14', total14,
        'total21', total21,
        'total28', total28,
        'total35', total35,
        'total42', total42,
        'total49', total49,
        'total56', total56,
        'total63', total63,
        'total70', total70,
        'total77', total77,
        'total84', total84
    ) AS days_agg, stores
),

trials AS (
    SELECT 
        date,
        country,
        device,
        is_affiliate,
        is_store_blocked,
        COUNT(DISTINCT store_id) AS trials
    FROM base
    GROUP BY date, country, device, is_affiliate, is_store_blocked
)

SELECT 
    u.date,
    u.country,
    u.device,
    u.is_affiliate,
    u.is_store_blocked,
    u.days_agg,
    u.stores,
    t.trials
FROM unpivoted u
LEFT JOIN trials t
    ON u.date = t.date
    AND u.country = t.country
    AND u.device = t.device
    AND u.is_affiliate = t.is_affiliate
    AND u.is_store_blocked = t.is_store_blocked