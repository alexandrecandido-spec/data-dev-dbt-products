SELECT 
    store_id,
    domain,
    state,
    country AS country_code,
    currency,
    current_segment,
    first_payment AS first_payment_ts,
    churned_at AS churned_at_ts,
    created_at AS created_at_ts,
    plan AS plan_id,
    verified,
    main_user_id,
    partner_id,
    partnership_type
FROM {{ ref('moltres__mwp_store_info') }}
WHERE partner_id IS NOT NULL -- Partner related
    AND partnership_type IN('store_development', 'affiliate'); -- Agencies and affiliates