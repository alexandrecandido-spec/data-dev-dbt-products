-- Weekly WhatsApp
with weekly_whatsapp AS (
    SELECT 
        CAST(CAST(deal AS DOUBLE) AS BIGINT) AS deal_id,
        CAST(date_trunc('week', createdate) AS DATE) AS date_from,
        COUNT(DISTINCT communication_id) AS whatsapp
    FROM (
        SELECT *, explode(split(associated_deal, ';')) AS deal
        FROM {{ source("int_third_party", "midmarket_hubspot_communications") }}
    ) c
    INNER JOIN {{ ref('midmarket_success_stores') }} sid 
        ON CAST(CAST(c.deal AS DOUBLE) AS BIGINT) = sid.deal_id
    WHERE 
        communication_channel_type = 'WhatsApp'
        AND createdate < date_trunc('week', current_date)
    GROUP BY CAST(CAST(deal AS DOUBLE) AS BIGINT), CAST(date_trunc('week', createdate) AS DATE)
),

-- Monthly WhatsApp
monthly_whatsapp AS (
    SELECT 
        CAST(CAST(deal AS DOUBLE) AS BIGINT) AS deal_id,
        CAST(date_trunc('month', createdate) AS DATE) AS date_from,
        COUNT(DISTINCT communication_id) AS whatsapp
    FROM (
        SELECT *, explode(split(associated_deal, ';')) AS deal
        FROM {{ source("int_third_party", "midmarket_hubspot_communications") }}
    ) c
    INNER JOIN {{ ref('midmarket_success_stores') }} sid 
        ON CAST(CAST(c.deal AS DOUBLE) AS BIGINT) = sid.deal_id
    WHERE 
        communication_channel_type = 'WhatsApp'
        AND createdate < date_trunc('month', current_date)
    GROUP BY CAST(CAST(deal AS DOUBLE) AS BIGINT), CAST(date_trunc('month', createdate) AS DATE)
)

select
    deal_id,
    date_from,
    'weekly' as periodicity,
    coalesce(whatsapp, 0) as whatsapp
from weekly_whatsapp ww

union all

select
    deal_id,
    date_from,
    'monthly' as periodicity,
    coalesce(whatsapp, 0) as whatsapp
from monthly_whatsapp mw