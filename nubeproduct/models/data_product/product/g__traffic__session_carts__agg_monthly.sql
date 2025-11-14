-- Brings aggregated info about sessions, including the carts generated and their GMV
-- GMV fields are included for funnel tracking only. For official revenue figures, refer to Finance data products.

{{ config(
   materialized = 'incremental',
   incremental_strategy='merge',
   unique_key = ['base_month', 'store_id', 'country_code', 'vertical_name', 'current_plan_type', 'current_segment'
        , 'is_store_blocked' , 'visitor_country', 'device', 'theme', 'source_name', 'source_group'  
        , 'google_subchannel', 'traffic_type', 'is_end_user', 'storefront'],
   partition_by = 'base_month',
   on_schema_change = 'fail',
   tags = ['daily-2am']
) }}

WITH base_data AS (
SELECT
    *
FROM
    {{ ref('_int_product__session_agg_prep')}}
)

, dedup_data AS (
SELECT
    *
FROM (
    SELECT
        *
        , ROW_NUMBER() OVER (PARTITION BY unique_session_key ORDER BY session_timestamp ASC) AS rnk
    FROM base_data)
WHERE
    rnk = 1
)

, agg_1 AS (
SELECT
    DATE_TRUNC('month', base_date) AS base_month
    , store_id
    , country_code
    , vertical_name
    , current_plan_type
    , current_segment
    , is_store_blocked
    , visitor_country
    , device
    , theme
    , source_name
    , source_group
    , google_subchannel
    , traffic_type
    , is_end_user 
    , storefront
    , COUNT(unique_session_key) AS total_sessions
    , COUNT(DISTINCT unique_session_key) AS total_unique_sessions
    , COUNT(DISTINCT session_id) AS total_unique_session_ids
    , COUNT(DISTINCT consumer_id) AS total_unique_consumer_ids
    , COUNT(cart_id) AS total_sessions_with_carts
    , COUNT(DISTINCT cart_id) AS total_sessions_with_unique_carts
    , COUNT(DISTINCT (CASE WHEN total_in_usd IS NOT NULL THEN cart_id ELSE NULL END)) AS total_sessions_with_paid_orders
    , SUM((total_in_usd)) AS total_usd_sessions_with_paid_orders
FROM
    dedup_data
{{ dbt_utils.group_by(16) }}
)

SELECT
    agg_1.*
    , CURRENT_TIMESTAMP AS sys_audit_created_on 
    , 'data-dev-dbt-products' AS sys_audit_created_by
    , CURRENT_TIMESTAMP AS sys_audit_updated_on
    , 'data-dev-dbt-products' AS sys_audit_updated_by
FROM
    agg_1
