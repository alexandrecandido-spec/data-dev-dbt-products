-- Weekly Emails
with weekly_emails AS (
    SELECT 
        CAST(deal AS BIGINT) AS deal_id,
        CAST(date_trunc('week', CAST(email_timestamp AS TIMESTAMP)) AS DATE) AS date_from,
        COUNT(DISTINCT email_id) AS emails
    FROM (
        SELECT *, explode(split(associations_deal_ids, ';')) AS deal
        FROM {{ source("int_third_party", "midmarket_hubspot_email") }}
    ) em
    INNER JOIN {{ ref('midmarket_success_stores') }} sid 
        ON CAST(em.deal AS BIGINT) = sid.deal_id
    WHERE 
        email_status = 'Sent'
        AND email_direction = 'Outgoing'
        AND CAST(email_timestamp AS TIMESTAMP) < date_trunc('week', current_date)
    GROUP BY CAST(deal AS BIGINT), CAST(date_trunc('week', CAST(email_timestamp AS TIMESTAMP)) AS DATE)
),

-- Monthly Emails
monthly_emails AS (
    SELECT 
        CAST(deal AS BIGINT) AS deal_id,
        CAST(date_trunc('month', CAST(email_timestamp AS TIMESTAMP)) AS DATE) AS date_from,
        COUNT(DISTINCT email_id) AS emails
    FROM (
        SELECT *, explode(split(associations_deal_ids, ';')) AS deal
        FROM {{ source("int_third_party", "midmarket_hubspot_email") }}
    ) em
    INNER JOIN {{ ref('midmarket_success_stores') }} sid 
        ON CAST(em.deal AS BIGINT) = sid.deal_id
    WHERE 
        email_status = 'Sent'
        AND email_direction = 'Outgoing'
        AND CAST(email_timestamp AS DATE) < date_trunc('month', current_date)
    GROUP BY CAST(deal AS BIGINT), CAST(date_trunc('month', CAST(email_timestamp AS TIMESTAMP)) AS DATE)
)

select
    deal_id,
    date_from,
    'weekly' as periodicity,
    coalesce(emails, 0) as emails
from weekly_emails we

union all

select
    deal_id,
    date_from,
    'monthly' as periodicity,
    coalesce(emails, 0) as emails
from monthly_emails me