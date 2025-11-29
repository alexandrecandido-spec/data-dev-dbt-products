-- Weekly Meetings
with weekly_meetings AS (
    SELECT 
        CAST(deal AS BIGINT) AS deal_id,
        CAST(date_trunc('week', activity_date) AS DATE) AS date_from,
        COUNT(DISTINCT meeting_id) AS meetings
    FROM (
        SELECT *, explode(split(associated_deal, ';')) AS deal
        FROM {{ source("int_third_party", "midmarket_hubspot_meetings") }}
    ) m
    INNER JOIN {{ ref('midmarket_success_stores') }} sid 
        ON CAST(m.deal AS BIGINT) = sid.deal_id
    INNER JOIN {{ ref('_int_midmarket_wbr_mbr__reps') }} r
        ON m.hubspot_owner_id = r.hubspot_owner_id
    INNER JOIN {{ source('int_third_party', 'midmarket_hubspot_deals') }} d 
        ON sid.deal_id = d.deal_id
    WHERE 
        meeting_outcome = 'Completed'
        AND (call_and_meeting_type IS NULL OR call_and_meeting_type != 'CS - Non-Value Interaction')
        AND activity_date < date_trunc('week', current_date)
        AND r.hubspot_owner_id is not null
        AND activity_date::date >= d.createdate::date
    GROUP BY CAST(deal AS BIGINT), CAST(date_trunc('week', activity_date) AS DATE)
),

-- Monthly Meetings
monthly_meetings AS (
    SELECT 
        CAST(deal AS BIGINT) AS deal_id,
        CAST(date_trunc('month', activity_date) AS DATE) AS date_from,
        COUNT(DISTINCT meeting_id) AS meetings
    FROM (
        SELECT *, explode(split(associated_deal, ';')) AS deal
        FROM {{ source("int_third_party", "midmarket_hubspot_meetings") }}
    ) m
    INNER JOIN {{ ref('midmarket_success_stores') }} sid 
        ON CAST(m.deal AS BIGINT) = sid.deal_id
    INNER JOIN {{ ref('_int_midmarket_wbr_mbr__reps') }} r
        ON m.hubspot_owner_id = r.hubspot_owner_id
    INNER JOIN {{ source('int_third_party', 'midmarket_hubspot_deals') }} d 
        ON sid.deal_id = d.deal_id
    WHERE 
        meeting_outcome = 'Completed'
        AND (call_and_meeting_type IS NULL OR call_and_meeting_type != 'CS - Non-Value Interaction')
        AND activity_date < date_trunc('month', current_date)
        AND r.hubspot_owner_id is not null
        AND activity_date::date >= d.createdate::date
    GROUP BY CAST(deal AS BIGINT), CAST(date_trunc('month', activity_date) AS DATE)
)

select
    deal_id,
    date_from,
    'weekly' as periodicity,
    coalesce(meetings, 0) as meetings
from weekly_meetings wm

union all

select
    deal_id,
    date_from,
    'monthly' as periodicity,
    coalesce(meetings, 0) as meetings
from monthly_meetings mm