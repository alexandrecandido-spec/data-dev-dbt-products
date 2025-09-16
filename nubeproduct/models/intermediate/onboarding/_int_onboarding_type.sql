WITH onb_types AS (
    SELECT 
        store_id,
        onboarding_type
    FROM
        {{ ref('onboarding__preference_types') }}
)

SELECT
    store_id,
    COUNT(CASE WHEN onboarding_type = 'online_store' THEN store_id ELSE NULL END) AS onb_type_online,
    COUNT(CASE WHEN onboarding_type = 'pos' THEN store_id ELSE NULL END) AS onb_type_offline,
    COUNT(CASE WHEN onboarding_type = 'chat' THEN store_id ELSE NULL END) AS onb_type_chat
FROM
    onb_types
GROUP BY
    store_id
    