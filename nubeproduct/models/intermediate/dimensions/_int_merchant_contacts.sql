WITH store_settings AS (
    SELECT
        store_id,
        phone,
        whatsapp_phone_number AS whatsapp,
        CASE 
            WHEN owner_phone_number LIKE '+%' THEN owner_phone_number
            ELSE CONCAT('+', owner_phone_country, owner_phone_area, owner_phone_number)
        END AS owner_phone
    FROM {{ source('int_moltres', 'mwp_store_settings') }}
),

wp_users AS (
    SELECT
        store_id,
        id AS main_user_id,
        user_email AS user_email_wp,
        ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY id DESC) AS rn
    FROM {{ source('int_moltres', 'wp_users') }}
),

latest_user_per_store AS (
    SELECT
        store_id,
        main_user_id,
        user_email_wp
    FROM wp_users
    WHERE rn = 1
),

store_info AS (
    SELECT
        id AS store_id,
        email_marketing AS user_email_info
    FROM {{ source('int_moltres', 'mwp_store_info') }}
)

SELECT
    ss.store_id,
    u.main_user_id,
    COALESCE(u.user_email_wp, i.user_email_info) AS email,
    ss.phone,
    ss.whatsapp,
    ss.owner_phone
FROM store_settings ss
LEFT JOIN latest_user_per_store u ON ss.store_id = u.store_id
LEFT JOIN store_info i ON ss.store_id = i.store_id
