-- Owner: YAN GERMANO
-- Model: acquisition_attribution_metrics_gold

WITH base_trials_clicks AS (
    -- Métrica: Trials e Clicks (atribuídos por created_at)
    SELECT
        ag.store_id,
        ag.country_code,
        ag.created_at AS date,
        ag.source,
        ag.medium,
        ag.campaign,
        ag.content,
        ag.http_referrer,
        ag.landing_page,
        ag.device,
        ag.tipo,
        ag.status,
        ag.flux,
        ag.email_name,

        -- Métricas de Trials e Payments (Multi-Click)
        COUNT(DISTINCT ag.store_id) AS trials_multi_click,
        COUNT(CASE WHEN ag.new_payment = true THEN ag.store_id ELSE NULL END) AS payment_multi_click,
        COUNT(DISTINCT ag.click_id) AS clicks,

        -- Métricas de Trials (Attribution Models)
        SUM(att.trials_mean_click) AS trials_mean_click,
        SUM(att.trials_last_click) AS trials_last_click,

        -- Métricas de Payments (Attribution Models)
        SUM(CASE WHEN ag.new_payment = true THEN att.trials_last_click  ELSE 0 END) AS payment_last_click,
        SUM(CASE WHEN ag.new_payment = true THEN att.trials_mean_click  ELSE 0 END) AS payment_mean_click,

        -- Inicialização de colunas que não aplicam nesta CTE (Pagamentos/Vendas por first_payment/first_seller_at)
        CAST(NULL AS BIGINT) AS new_payment_multi_click,
        CAST(NULL AS BIGINT) AS new_payment_last_click,
        CAST(NULL AS BIGINT) AS new_payment_mean_click,
        CAST(NULL AS BIGINT) AS new_seller_multi_click,
        CAST(NULL AS BIGINT) AS new_seller_last_click,
        CAST(NULL AS BIGINT) AS new_seller_mean_click,

        MAX(ag.change_timestamp) as change_timestamp
    FROM {{ ref('_int__acquisition__nurturing_growth') }} AS ag
    LEFT JOIN {{ ref('s__general__mkt_attribution_model__event') }} att
        ON ag.click_id = att.click_id AND ag.store_id = att.store_id
    GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14
),

base_new_payment AS (
    -- Métrica: New Payments (atribuídos por first_payment)
    SELECT
        ag.store_id,
        ag.country_code,
        ag.first_payment AS date,
        ag.source,
        ag.medium,
        ag.campaign,
        ag.content,
        ag.http_referrer,
        ag.landing_page,
        ag.device,
        ag.tipo,
        ag.status,
        ag.flux,
        ag.email_name,

        -- Inicialização de colunas que não aplicam nesta CTE (Trials/Payments por created_at/first_seller_at)
        CAST(NULL AS BIGINT) AS trials_multi_click,
        CAST(NULL AS BIGINT) AS payment_multi_click,
        CAST(0 AS INTEGER) AS clicks,
        CAST(NULL AS BIGINT) AS trials_mean_click,
        CAST(NULL AS BIGINT) AS trials_last_click,
        CAST(NULL AS BIGINT) AS payment_last_click,
        CAST(NULL AS BIGINT) AS payment_mean_click,

        -- Métricas de New Payments (Attribution Models)
        COUNT(CASE WHEN ag.new_payment = true THEN ag.store_id ELSE NULL END) AS new_payment_multi_click,
        SUM(CASE WHEN ag.new_payment = true THEN att.trials_last_click  ELSE 0 END) AS new_payment_last_click,
        SUM(CASE WHEN ag.new_payment = true THEN att.trials_mean_click  ELSE 0 END) AS new_payment_mean_click,

        -- Inicialização de colunas que não aplicam nesta CTE (New Sellers)
        CAST(NULL AS BIGINT) AS new_seller_multi_click,
        CAST(NULL AS BIGINT) AS new_seller_last_click,
        CAST(NULL AS BIGINT) AS new_seller_mean_click,

        MAX(ag.change_timestamp) as change_timestamp
    FROM {{ ref('_int__acquisition__nurturing_growth') }} AS ag
    LEFT JOIN {{ ref('s__general__mkt_attribution_model__event') }} att
        ON ag.click_id = att.click_id AND ag.store_id = att.store_id
    WHERE ag.new_payment = TRUE -- Considera apenas eventos que levaram a um New Payment
    GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14
),

base_new_seller AS (
    -- Métrica: New Sellers (atribuídos por first_seller_at)
    SELECT
        ag.store_id,
        ag.country_code,
        ag.first_seller_at AS date,
        ag.source,
        ag.medium,
        ag.campaign,
        ag.content,
        ag.http_referrer,
        ag.landing_page,
        ag.device,
        ag.tipo,
        ag.status,
        ag.flux,
        ag.email_name,

        -- Inicialização de colunas que não aplicam nesta CTE (Trials/Payments por created_at/first_payment)
        CAST(NULL AS BIGINT) AS trials_multi_click,
        CAST(NULL AS BIGINT) AS payment_multi_click,
        CAST(0 AS INTEGER) AS clicks,
        CAST(NULL AS BIGINT) AS trials_mean_click,
        CAST(NULL AS BIGINT) AS trials_last_click,
        CAST(NULL AS BIGINT) AS payment_last_click,
        CAST(NULL AS BIGINT) AS payment_mean_click,
        CAST(NULL AS BIGINT) AS new_payment_multi_click,
        CAST(NULL AS BIGINT) AS new_payment_last_click,
        CAST(NULL AS BIGINT) AS new_payment_mean_click,

        -- Métricas de New Sellers (Attribution Models)
        COUNT(CASE WHEN ag.new_seller = true THEN ag.store_id ELSE NULL END) AS new_seller_multi_click,
        SUM(CASE WHEN ag.new_seller = true THEN att.trials_last_click  ELSE 0 END) AS new_seller_last_click,
        SUM(CASE WHEN ag.new_seller = true THEN att.trials_mean_click  ELSE 0 END) AS new_seller_mean_click,

        MAX(ag.change_timestamp) as change_timestamp
    FROM {{ ref('_int__acquisition__nurturing_growth') }} AS ag
    LEFT JOIN {{ ref('s__general__mkt_attribution_model__event') }} att
        ON ag.click_id = att.click_id AND ag.store_id = att.store_id
    WHERE ag.new_seller = TRUE -- Considera apenas eventos que levaram a um New Seller
    GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14
),

all_metrics AS (
    -- Consolidação de todas as CTEs de Métricas
    SELECT * FROM base_trials_clicks
    UNION ALL
    SELECT * FROM base_new_payment
    UNION ALL
    SELECT * FROM base_new_seller
)

SELECT
    store_id,
    date,
    country_code,
    source,
    medium,
    campaign,
    content,
    http_referrer,
    landing_page,
    device,
    tipo,
    status,
    flux,
    email_name,

    -- Soma das métricas de Trials e Clicks (base_trials_clicks)
    SUM(trials_multi_click) AS trials_multi_click,
    SUM(clicks) AS clicks,
    SUM(trials_mean_click) AS trials_mean_click,
    SUM(trials_last_click) AS trials_last_click,

    -- Soma das métricas de Payments (base_trials_clicks)
    SUM(payment_multi_click) AS payment_multi_click,
    SUM(payment_last_click) AS payment_last_click,
    SUM(payment_mean_click) AS payment_mean_click,

    -- Soma das métricas de New Payments (base_new_payment)
    SUM(new_payment_multi_click) AS new_payment_multi_click,
    SUM(new_payment_last_click) AS new_payment_last_click,
    SUM(new_payment_mean_click) AS new_payment_mean_click,

    -- Soma das métricas de New Sellers (base_new_seller)
    SUM(new_seller_multi_click) AS new_seller_multi_click,
    SUM(new_seller_last_click) AS new_seller_last_click,
    SUM(new_seller_mean_click) AS new_seller_mean_click,

    MAX(change_timestamp) as change_timestamp
FROM all_metrics
GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14