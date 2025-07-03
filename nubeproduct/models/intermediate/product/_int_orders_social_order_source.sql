WITH paid_orders AS (
    SELECT DISTINCT id
    FROM {{ ref('_int_company_metrics_paid_orders__get_store_info') }}
),

filtered_traffic AS (
    SELECT 
        t.*, 
        p.year_month_day_code,
        p.completed_at
    FROM {{ ref('orders__mwp_orders_source') }} t
    INNER JOIN paid_orders p ON t.order_id = p.id
)

SELECT
    order_id,
    utm_source,
    utm_medium,
    http_referrer,
    source,
    source_details,
    completed_at,
    year_month_day_code,

    -- Classificação do canal (nome)
    CASE 
        WHEN utm_source = 'ig'
            OR utm_source LIKE '%instagram%'
            OR (utm_source LIKE '%ig%' AND utm_source LIKE '%ads%')
            OR utm_source LIKE '%igshopping%'
            OR utm_medium LIKE '%instagram%' THEN 'instagram'
        WHEN utm_source IN ('fb', 'fbads', 'fb_ads', 'face_ads')
            OR utm_source LIKE '%facebook%'
            OR (utm_source LIKE '%fb%' AND utm_source LIKE '%ads%')
            OR utm_medium LIKE '%facebook%' THEN 'facebook'
        WHEN utm_source LIKE '%tiktok%' OR utm_source LIKE '%ttkads%' THEN 'tiktok'
        WHEN utm_source LIKE '%twitter%' THEN 'twitter'
        WHEN utm_source LIKE '%bing%' THEN 'bing'
        WHEN utm_source LIKE '%hubspot%' THEN 'hubspot'
        WHEN utm_source LIKE '%email%' OR utm_medium LIKE '%email%' THEN 'email'
        WHEN utm_source LIKE '%pinterest%' OR utm_medium LIKE '%pinterest%' THEN 'pinterest'
        WHEN utm_source LIKE '%anthropic%' OR utm_source LIKE '%claude%' THEN 'claude'
        WHEN utm_source LIKE '%chatgpt%' THEN 'chatgpt'
        WHEN utm_source LIKE '%gemini%' THEN 'gemini'
        WHEN utm_source LIKE '%google%' OR utm_source LIKE '%gads%' THEN 'google'

        WHEN http_referrer LIKE '%instagram%' THEN 'instagram'
        WHEN http_referrer LIKE '%facebook%' THEN 'facebook'
        WHEN utm_source LIKE '%meta%' OR http_referrer LIKE '%fbclid%' THEN 'meta'
        WHEN http_referrer LIKE '%tiktok%' THEN 'tiktok'
        WHEN http_referrer LIKE '%whatsapp%' OR http_referrer LIKE '%wl.co%' THEN 'whatsapp'
        WHEN http_referrer LIKE '%linktr.ee%' THEN 'linktree'
        WHEN http_referrer LIKE '%bing%' THEN 'bing'
        WHEN http_referrer LIKE '%t.co/%' THEN 'twitter'
        WHEN http_referrer LIKE '%pinterest%' THEN 'pinterest'
        WHEN http_referrer LIKE '%chatgpt%' THEN 'chatgpt'
        WHEN http_referrer LIKE '%claude.ai%' THEN 'claude'
        WHEN http_referrer LIKE '%gemini.google.com%' THEN 'gemini'
        WHEN http_referrer LIKE '%perplexity.ai%' THEN 'perplexity'
        WHEN http_referrer LIKE '%google%' 
            OR http_referrer LIKE '%syndicatedsearch.goog%' 
            OR http_referrer LIKE '%adsensecustomsearchads%' THEN 'google'

        WHEN source IS NULL AND (
            (http_referrer IS NULL OR http_referrer = '')
            AND utm_source IS NULL 
            AND utm_medium IS NULL
        ) THEN 'direct'

        ELSE source
    END AS source_name,

    -- Classificação orgânico vs pago
    CASE 
        WHEN utm_medium IN ('cpc', 'ppc', 'paid', 'paidsocial', 'paid_social', 'display', 'affiliate', 'ads') THEN 'paid'
        WHEN utm_medium LIKE '%cpc%' 
            OR utm_medium LIKE '%paid%' 
            OR utm_medium LIKE '%adset%' 
            OR utm_medium LIKE '%adgroup%' 
            OR utm_medium LIKE '%ads%' THEN 'paid'
        WHEN utm_source = 'google' AND utm_medium LIKE '%sms%' THEN 'paid'
        WHEN utm_source LIKE '%ads%' OR utm_source LIKE '%vendas%' THEN 'paid'
        WHEN utm_source IN ('googlead', 'google-cpc', 'adwords', 'google-cpc') THEN 'paid'
        WHEN source_details LIKE '%ads%' THEN 'paid'
        WHEN http_referrer LIKE '%fbclid%' 
            OR http_referrer LIKE '%ttclid%' 
            OR http_referrer LIKE '%gclid%' 
            OR http_referrer LIKE '%googlead%'
            OR http_referrer LIKE '%ads.google%'
            OR http_referrer LIKE '%utm_medium=cpc%' THEN 'paid'
        ELSE 'organic'
    END AS source_type

FROM filtered_traffic
