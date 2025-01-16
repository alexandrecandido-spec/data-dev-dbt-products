{{
    config(
        materialized='view'
    )
}}


SELECT 
    lower(email) as user_email,
    max(consented_at) as wallet_consented_at
    
FROM {{ source('wallet', 'user') }}
WHERE with_consent = 1
GROUP BY lower(email)