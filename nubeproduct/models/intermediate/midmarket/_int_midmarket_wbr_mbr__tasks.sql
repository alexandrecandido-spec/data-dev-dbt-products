-- Weekly Tasks
with weekly_tasks AS (
    SELECT 
        CAST(deal AS BIGINT) AS deal_id,
        CAST(date_trunc('week', em.timestamp) AS DATE) AS date_from,
        COUNT(DISTINCT task_id) AS tasks
    FROM (
        SELECT *, explode(split(associated_deal, ';')) AS deal
        FROM {{ source("int_third_party", "midmarket_hubspot_tasks") }}
    ) em
    INNER JOIN {{ ref('midmarket_success_stores') }} sid 
        ON CAST(em.deal AS BIGINT) = sid.deal_id
    WHERE 
        task_status = 'Completed'
        AND em.timestamp < date_trunc('week', current_date)
    GROUP BY CAST(deal AS BIGINT), CAST(date_trunc('week', em.timestamp) AS DATE)
),

-- Monthly Tasks
monthly_tasks AS (
    SELECT 
        CAST(deal AS BIGINT) AS deal_id,
        CAST(date_trunc('month', em.timestamp) AS DATE) AS date_from,
        COUNT(DISTINCT task_id) AS tasks
    FROM (
        SELECT *, explode(split(associated_deal, ';')) AS deal
        FROM {{ source("int_third_party", "midmarket_hubspot_tasks") }}
    ) em
    INNER JOIN {{ ref('midmarket_success_stores') }} sid 
        ON CAST(em.deal AS BIGINT) = sid.deal_id
    WHERE 
        task_status = 'Completed'
        AND em.timestamp < date_trunc('month', current_date)
    GROUP BY CAST(deal AS BIGINT), CAST(date_trunc('month', em.timestamp) AS DATE)
)

select
    deal_id,
    date_from,
    'weekly' as periodicity,
    coalesce(tasks, 0) as tasks
from weekly_tasks wt

union all

select
    deal_id,
    date_from,
    'monthly' as periodicity,
    coalesce(tasks, 0) as tasks
from monthly_tasks mt