-- Owner: Guille De Felice

WITH calls_interactions AS (
    SELECT 
        CAST(deal AS BIGINT) AS deal_id,
        MAX(activity_date) AS last_call
    FROM (
        SELECT *, explode(split(associated_deal, ';')) AS deal
        FROM {{ source("int_third_party", "midmarket_hubspot_calls") }}
    ) c
    INNER JOIN {{ ref('midmarket_success_stores') }} sid 
        ON CAST(deal AS BIGINT) = sid.deal_id
    INNER JOIN {{ ref('_int_midmarket_wbr_mbr__reps') }} r
        ON c.activity_assigned_to = r.hubspot_owner_id
    INNER JOIN {{ source('int_third_party', 'midmarket_hubspot_deals') }} d 
        ON sid.deal_id = d.deal_id
    WHERE 
        call_status = 'Completed'
        AND (lower(call_outcome) = 'conectado'
            OR lower(call_outcome) like 'connected%')
        AND (call_and_meeting_type IS NULL OR call_and_meeting_type != 'CS - Non-Value Interaction')
        AND (activity_date < date_trunc('week', current_date) OR activity_date < date_trunc('month', current_date))
        AND r.hubspot_owner_id is not null
        AND activity_date::date >= d.createdate::date
    GROUP BY CAST(deal AS BIGINT)
),

meetings_interactions AS (
    SELECT 
        CAST(deal AS BIGINT) AS deal_id,
        MAX(activity_date) AS last_meeting
    FROM (
        SELECT *, explode(split(associated_deal, ';')) AS deal
        FROM {{ source("int_third_party", "midmarket_hubspot_meetings") }}
    ) m
    INNER JOIN {{ ref('midmarket_success_stores') }} sid 
        ON CAST(deal AS BIGINT) = sid.deal_id
    INNER JOIN {{ ref('_int_midmarket_wbr_mbr__reps') }} r
        ON m.hubspot_owner_id = r.hubspot_owner_id
    INNER JOIN {{ source('int_third_party', 'midmarket_hubspot_deals') }} d 
        ON sid.deal_id = d.deal_id
    WHERE 
        meeting_outcome = 'Completed'
        AND (call_and_meeting_type IS NULL OR call_and_meeting_type != 'CS - Non-Value Interaction')
        AND (activity_date < date_trunc('week', current_date) OR activity_date < date_trunc('month', current_date))
        AND r.hubspot_owner_id is not null
        AND activity_date::date >= d.createdate::date
    GROUP BY CAST(deal AS BIGINT)
)

SELECT 
    sid.store_id,
    GREATEST(ci.last_call, mi.last_meeting) AS last_relevant_interaction
FROM {{ ref('midmarket_success_stores') }} sid
LEFT JOIN calls_interactions ci 
    ON sid.deal_id = ci.deal_id
LEFT JOIN meetings_interactions mi 
    ON sid.deal_id = mi.deal_id