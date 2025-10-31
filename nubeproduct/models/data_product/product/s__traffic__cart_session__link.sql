-- For each cart_id, it gets information about the first session of a cart_id and returns the traffic origin and session details

{{ config(
    materialized = 'incremental',
    unique_key = 'cart_id',
    partition_by = 'event_base_date',
    on_schema_change = 'fail',
    tags = ['product', 'daily-4am']
) }}

WITH cart_add AS (
SELECT
    *
FROM 
    {{ ref('product__traffic__cart_product_add__event') }}
WHERE
    {% if not is_incremental() %}
    base_date BETWEEN DATE('2024-01-23') AND DATE('2024-01-30')
    {% else %}
    base_date {{ get_max_date(this, 'event_base_date', 2, 'week') }}
    {% endif %}
)

, filtered_session AS (
SELECT
    *
FROM
    {{ ref('s__traffic__session__event') }} AS fse
WHERE
    {% if not is_incremental() %}
    base_date BETWEEN DATE_ADD(DAY, -10, DATE('2024-01-23')) AND DATE('2024-01-30')
    {% else %}
    {% set interval = get_max_date(this, 'event_base_date', 2, 'week') %}
    {% set min_date_raw = interval.split(' ')[1] %}
    {% set min_date = min_date_raw %}
    {% set max_date = interval.split(' ')[-1] %}
    {% set session_start_date = "DATE_ADD(DAY, -10, " ~ min_date ~ ")" %}
    base_date BETWEEN {{ session_start_date }} AND {{ max_date }}
    {% endif %}
)

, cart_source AS (
SELECT
    cart_add.cart_id
    , cart_add.event_timestamp
    , cart_add.base_date AS event_base_date
    , cart_add.unique_session_key
    , fse.session_timestamp
    , fse.base_date AS session_base_date
    , fse.visitor_country
    , fse.ref_domain
    , fse.land_domain
    , fse.source_name
    , fse.source_group
    , fse.google_subchannel
    , fse.traffic_type
    , fse.is_end_user
FROM
    cart_add
LEFT JOIN
    filtered_session AS fse
    ON cart_add.unique_session_key = fse.unique_session_key
)

, deduped_sessions AS (
SELECT
    *
FROM (
    SELECT
        *
        , ROW_NUMBER() OVER (PARTITION BY cart_id ORDER BY event_timestamp ASC, session_timestamp ASC) AS row_num
    FROM cart_source
) sub
WHERE row_num = 1
)

, existing_data AS (
    {{ get_existing_data(this, ['cart_id'])}}
)

SELECT
    ds.cart_id
    , ds.event_timestamp
    , ds.event_base_date
    , ds.unique_session_key
    , ds.session_timestamp
    , ds.session_base_date
    , ds.visitor_country
    , ds.ref_domain
    , ds.land_domain
    , ds.source_name
    , ds.source_group
    , ds.google_subchannel
    , ds.traffic_type
    , ds.is_end_user
    , CURRENT_TIMESTAMP AS sys_audit_created_on
    , 'data-dev-dbt-products' AS sys_audit_created_by
    , CURRENT_TIMESTAMP AS sys_audit_updated_on
    , 'data-dev-dbt-products' AS sys_audit_updated_by
FROM
    deduped_sessions AS ds
LEFT JOIN
   existing_data
   ON ds.cart_id = existing_data.cart_id
WHERE
    existing_data.cart_id IS NULL