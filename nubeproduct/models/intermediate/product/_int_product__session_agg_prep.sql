-- Selects the information needed for the daily and monthly aggregations

SELECT
    base_sessions.unique_session_key
    , base_sessions.base_date
    , base_sessions.session_timestamp
    , base_sessions.session_id
    , base_sessions.consumer_id
    , base_sessions.store_id
    , COALESCE(merch_core.country_code, 'undefined') AS country_code
    , COALESCE(merch_core.vertical_name, 'undefined') AS vertical_name
    , COALESCE(merch_stats.current_plan_type, 'undefined') AS current_plan_type
    , COALESCE(merch_stats.current_segment, 'undefined') AS current_segment
    , COALESCE(merch_stats.is_store_blocked, FALSE) AS  is_store_blocked
    , COALESCE(base_sessions.visitor_country, 'undefined') AS visitor_country
    , COALESCE(base_sessions.device, 'undefined') AS device
    , COALESCE(base_sessions.theme, 'undefined') AS theme
    , COALESCE(base_sessions.source_name, 'others') AS source_name
    , COALESCE(base_sessions.source_group, 'others') AS source_group
    , COALESCE(base_sessions.google_subchannel, 'not_google') AS google_subchannel
    , COALESCE(base_sessions.traffic_type, 'organic') AS  traffic_type
    , COALESCE(base_sessions.is_end_user, TRUE) AS is_end_user
    , base_carts.cart_id
    , CASE  WHEN mo.storefront IS NOT NULL THEN mo.storefront
            WHEN mo.storefront IS NULL AND mo.id IS NOT NULL THEN 'unknown'
            ELSE 'undefined' END AS storefront
    , mo.total / exchange_rate.direct_exchange_rate AS total_in_usd
FROM
    {{ ref('s__traffic__session__event') }} AS base_sessions
INNER JOIN --removes stores with state = 4
    {{ ref('s__attributes__store_core__ref') }} AS merch_core
    ON base_sessions.store_id = merch_core.store_id
LEFT JOIN
    {{ ref('s__lifecycle__store_status__ref') }} AS merch_stats
    ON base_sessions.store_id = merch_stats.store_id
LEFT JOIN
    {{ ref('s__traffic__cart_session__link') }} AS base_carts
    ON base_sessions.unique_session_key = base_carts.unique_session_key
    AND base_sessions.base_date = base_carts.session_base_date
LEFT JOIN
    {{ ref('orders__mwp_orders') }} AS mo
    ON base_carts.cart_id = mo.id
    AND mo.is_paid_order = TRUE
    AND mo.total_in_usd >= 0 
    AND mo.total_in_usd <= 10000
LEFT JOIN 
    {{ ref('finance_exchange_rate') }} AS exchange_rate
    ON DATE(mo.completed_at) = DATE(exchange_rate.processed_at) 
    AND mo.currency = exchange_rate.isocode
WHERE
    {% set interval = get_max_date_env_model(
      'product',
      'g__traffic__session_carts__agg_daily',
      'base_date',
      1, 'MONTH',
      fallback_start='2024-01-01',
      fallback_end='2024-01-05'
    ) %}
    {% set min_date_raw = interval.split(' ')[1] %}
    {% set min_date = min_date_raw %}
    {% set max_date = interval.split(' ')[-1] %}
    {% set s_start_date = "DATE_ADD(MONTH, -1, DATE_TRUNC('MONTH', " ~ min_date ~ "))" %}
    base_sessions.base_date BETWEEN {{ s_start_date }} AND {{ max_date }}
