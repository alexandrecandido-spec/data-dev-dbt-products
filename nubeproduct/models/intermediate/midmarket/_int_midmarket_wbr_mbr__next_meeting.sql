SELECT 
    CAST(deal AS BIGINT) AS deal_id,
    ss.store_id,
    CAST(MIN(activity_date) AS DATE) as next_meeting
FROM (
    SELECT *, explode(split(associated_deal, ';')) AS deal
    FROM {{ source("int_third_party", "midmarket_hubspot_meetings") }}
    ) m
    INNER JOIN {{ ref('midmarket_success_stores') }} ss 
        ON CAST(m.deal AS BIGINT) = ss.deal_id
WHERE 
    activity_date >= current_date 
    and meeting_outcome IS DISTINCT FROM 'Completed'
GROUP BY 1, 2