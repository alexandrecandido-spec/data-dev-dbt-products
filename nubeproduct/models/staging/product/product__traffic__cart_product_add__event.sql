{{ config(
    materialized = 'incremental',
    unique_key = 'event_id',
    partition_by = 'base_date',
    on_schema_change = 'fail',
    tags = ['product','daily-2am']
) }}

WITH events AS (
SELECT
	-- common data: maintain the same layout
    event_id
    , timestamp AS event_timestamp
    , DATE(timestamp) AS base_date
    , MD5(CONCAT_WS('_', session_id, consumer_id, store_id)) AS unique_session_key
    , session_id
    , consumer_id
    , store_id
    , event
	-- specific columns related to layer/event
    , TRY_CAST(element_at(attributes, 'cart_id') AS BIGINT) AS cart_id
FROM
    {{ source('stg_storefronts', 'events') }}
WHERE 
	-- event selection
    event = 'cart_product_add'
    -- filters related to the layer/event 
    AND TRY_CAST(element_at(attributes, 'cart_id') AS BIGINT) > 0
    -- necessary code for historical incremental load and maintenance
    {% if not is_incremental() %}
    AND TO_DATE(year_month_code, 'yyyyMMdd') BETWEEN DATE('2024-01-20') AND DATE('2024-01-31')
    {% else %}
    AND TO_DATE(year_month_code, 'yyyyMMdd') {{ get_max_date(this, 'base_date', 4, 'month') }}
    {% endif %}
)

, rnk_events AS (
SELECT
    events.*
    , ROW_NUMBER() OVER (PARTITION BY unique_session_key, cart_id ORDER BY event_timestamp ASC) AS rnk
FROM
    events
)

SELECT 
    event_id
    , event_timestamp
    , base_date
    , unique_session_key
    , session_id
    , consumer_id
    , store_id
    , event
    , cart_id
    , CURRENT_TIMESTAMP AS sys_audit_created_on
    , 'data-dev-dbt-products' AS sys_audit_created_by
    , CURRENT_TIMESTAMP AS sys_audit_updated_on
    , 'data-dev-dbt-products' AS sys_audit_updated_by
FROM 
    rnk_events
WHERE
    rnk = 1
