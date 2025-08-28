-- Owner: Guille De Felice

WITH get_status AS (
    SELECT 
        d.store_id,
        CAST(current_date AS DATE) as date_to,
        p.country,
        dealstage,
        l.success_priority,
        not_unknown_reason,
        CAST(coalesce(fg.last_group_interaction, lri.last_relevant_interaction) AS DATE) as final_last_relevant_interaction
    FROM {{ source('int_third_party', 'midmarket_hubspot_deals') }} d
    INNER JOIN {{ ref('midmarket_success_stores') }} ss
        ON d.deal_id = ss.deal_id
    LEFT JOIN {{ ref('_int_midmarket_wbr_mbr__last_relevant_interaction') }} lri
        ON ss.store_id = lri.store_id
    LEFT JOIN {{ ref('_int_midmarket_wbr_mbr__franchise_group') }} fg
        ON ss.store_id = fg.store_id
    left join {{ ref('_int_midmarket_wbr_mbr__level') }} l
      on d.deal_id = l.deal_id
    left join {{ ref('_int_midmarket_wbr_mbr__plan') }} p
      on d.store_id = p.store_id
)

SELECT 
    store_id,
    date_diff(DAY, final_last_relevant_interaction, date_to) as days_since_last_relevant_interaction,
    CASE 
        -- Negative playbooks
        WHEN 
            dealstage IN ('Pre-onboarding', 'Out of portfolio', 'Effective churn', 'Warning')
            THEN dealstage
        
        -- BR, MX
        WHEN 
            country IN ('BR', 'MX')
            AND success_priority = '1'
            AND date_diff(DAY, final_last_relevant_interaction, date_to) < 30
            THEN 'Ok'

        WHEN 
            country IN ('BR', 'MX')
            AND (success_priority IN ('2', 'No tier') OR success_priority IS NULL)
            AND date_diff(DAY, final_last_relevant_interaction, date_to) < 45
            THEN 'Ok'

        WHEN 
            country IN ('BR', 'MX')
            AND success_priority = '3'
            AND date_diff(DAY, final_last_relevant_interaction, date_to) < 60
            THEN 'Ok'

        -- AR
        WHEN 
            country = 'AR'
            AND (success_priority IN ('1', '2', 'No tier') OR success_priority IS NULL)
            AND date_diff(DAY, final_last_relevant_interaction, date_to) < 45
            THEN 'Ok'

        WHEN 
            country = 'AR'
            AND success_priority = '3'
            AND date_diff(DAY, final_last_relevant_interaction, date_to) < 60
            THEN 'Ok'

        -- Unknown or OK
        WHEN 
            not_unknown_reason = '' OR not_unknown_reason IS NULL
            THEN 'Unknown'
        
        ELSE 
            'Ok'
    END AS status
FROM get_status