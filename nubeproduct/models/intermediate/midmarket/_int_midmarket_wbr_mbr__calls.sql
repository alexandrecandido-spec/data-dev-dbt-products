-- Weekly Calls
with weekly_calls AS (
    SELECT 
        CAST(deal AS BIGINT) AS deal_id,
        CAST(date_trunc('week', activity_date) AS DATE) AS date_from,
        COUNT(DISTINCT record_id) AS calls
    FROM (
        SELECT *, explode(split(associated_deal, ';')) AS deal
        FROM {{ source("int_third_party", "midmarket_hubspot_calls") }}
    ) c
    INNER JOIN {{ ref('midmarket_success_stores') }} sid 
        ON CAST(c.deal AS BIGINT) = sid.deal_id
    WHERE 
        call_status = 'Completed'
        AND (call_and_meeting_type IS NULL OR call_and_meeting_type != 'CS - Non-Value Interaction')
        AND activity_date < date_trunc('week', current_date)
    GROUP BY CAST(deal AS BIGINT), CAST(date_trunc('week', activity_date) AS DATE)
),

-- Monthly Calls
monthly_calls AS (
    SELECT 
        CAST(deal AS BIGINT) AS deal_id,
        CAST(date_trunc('month', activity_date) AS DATE) AS date_from,
        COUNT(DISTINCT record_id) AS calls
    FROM (
        SELECT *, explode(split(associated_deal, ';')) AS deal
        FROM {{ source("int_third_party", "midmarket_hubspot_calls") }}
    ) c
    INNER JOIN {{ ref('midmarket_success_stores') }} sid 
        ON CAST(c.deal AS BIGINT) = sid.deal_id
    WHERE 
        call_status = 'Completed'
        AND (call_and_meeting_type IS NULL OR call_and_meeting_type != 'CS - Non-Value Interaction')
        AND activity_date < date_trunc('month', current_date)
    GROUP BY CAST(deal AS BIGINT), CAST(date_trunc('month', activity_date) AS DATE)
)

select
    deal_id,
    date_from,
    'weekly' as periodicity,
    coalesce(calls, 0) as calls
from weekly_calls wc 

union all

select
    deal_id,
    date_from,
    'monthly' as periodicity,
    coalesce(calls, 0) as calls
from monthly_calls mc