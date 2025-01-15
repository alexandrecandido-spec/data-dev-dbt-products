WITH checkout_emails AS (
    SELECT 
        attributes_cart_id AS order_id,
        event,
        timestamp - interval '3' hour AS event_registration_at,
        attributes_contact_email AS contact_email,
        has_shipping_option,
        ROW_NUMBER() OVER (PARTITION BY attributes_cart_id,event ORDER BY timestamp ASC) AS rownum

    FROM {{ ref('stg_online__events') }})

SELECT
    *
FROM checkout_emails
WHERE rownum = 1
    
      