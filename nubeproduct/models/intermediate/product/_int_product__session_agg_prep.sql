-- Selects the information needed for the daily and monthly aggregations

SELECT
    base_sessions.unique_session_key
    , base_sessions.base_date
    , base_sessions.session_timestamp
    , base_sessions.session_id
    , base_sessions.consumer_id
    , base_sessions.store_id
    , merch_core.country_code
    , merch_core.vertical_name
    , merch_stats.current_plan_type
    , merch_stats.current_segment
    , merch_stats.is_store_blocked
    , base_sessions.visitor_country
    , base_sessions.device
    , base_sessions.theme
    , base_sessions.source_name
    , base_sessions.source_group
    , base_sessions.google_subchannel
    , base_sessions.traffic_type
    , base_sessions.is_end_user
    , base_carts.cart_id
    , mo.storefront
    , mo.total_in_usd
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
    AND mo.total_in_usd < 10000
WHERE
    {% set interval = get_max_date_env_model(
      'product',
      'g__traffic__session_carts__agg_daily',
      'base_date',
      1, 'month',
      fallback_start='2024-01-01',
      fallback_end='2024-01-05'
    ) %}
    {% set min_date_raw = interval.split(' ')[1] %}
    {% set min_date = min_date_raw %}
    {% set max_date = interval.split(' ')[-1] %}
    {% set s_start_date = "DATE_ADD(MONTH, -1, DATE_TRUNC('MONTH', " ~ min_date ~ "))" %}
    base_sessions.base_date BETWEEN {{ s_start_date }} AND {{ max_date }}
