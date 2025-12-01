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
    INNER JOIN {{ ref('_int_midmarket_wbr_mbr__reps') }} r
        ON m.hubspot_owner_id = r.hubspot_owner_id
    INNER JOIN {{ source('int_third_party', 'midmarket_hubspot_deals') }} d 
        ON ss.deal_id = d.deal_id
WHERE 
    activity_date >= current_date 
    and meeting_outcome IS DISTINCT FROM 'Completed'
    and r.hubspot_owner_id is not null
    and activity_date::date >= d.createdate::date
GROUP BY 1, 2