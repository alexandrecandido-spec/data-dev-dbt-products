{{ config(
    materialized        = "incremental",
    incremental_strategy= "merge",
    partition_by        = "year_month_day_code",
    unique_key          = "surrogate_key",
    on_schema_change    = "fail",
    tags                = ["daily-9am"]
) }}

WITH existing_data AS (
    {{ get_existing_data(this, [
        "surrogate_key",
        "sys_audit_created_on", "sys_audit_created_by", "sys_audit_updated_on"
    ]) }}
),

base_data AS (
    SELECT 
        *,
        MD5(
            CONCAT_WS('|',
                COALESCE(CAST(country AS STRING), ''),
                COALESCE(CAST(vertical AS STRING), ''),
                COALESCE(CAST(province AS STRING), ''),
                COALESCE(CAST(city AS STRING), ''),
                COALESCE(CAST(region AS STRING), ''),
                COALESCE(CAST(business_size AS STRING), ''),
                COALESCE(CAST(max_seller_segment AS STRING), ''),
                COALESCE(CAST(current_seller_segment AS STRING), ''),
                COALESCE(CAST(historical_seller_segment AS STRING), ''),
                COALESCE(CAST(current_plan AS STRING), ''),
                COALESCE(CAST(historical_plan AS STRING), ''),
                COALESCE(CAST(current_bu AS STRING), ''),
                COALESCE(CAST(historical_bu AS STRING), ''),
                COALESCE(CAST(date AS STRING), ''),
                COALESCE(CAST(year_month_day_code AS STRING), ''),
                COALESCE(CAST(datemonth AS STRING), ''),
                COALESCE(CAST(platform_type AS STRING), ''),
                COALESCE(CAST(storefront AS STRING), ''),
                COALESCE(CAST(device AS STRING), ''),
                COALESCE(CAST(payment_provider AS STRING), ''),
                COALESCE(CAST(payment_method AS STRING), ''),
                COALESCE(CAST(shipping_method AS STRING), ''),
                COALESCE(CAST(shipping_province AS STRING), ''),
                COALESCE(CAST(gateway_installments AS STRING), ''),
                COALESCE(CAST(source_name AS STRING), ''),
                COALESCE(CAST(source_group AS STRING), ''),
                COALESCE(CAST(google_subchannel AS STRING), ''),
                COALESCE(CAST(traffic_type AS STRING), ''),
                COALESCE(CAST(is_end_user AS STRING), ''),
                COALESCE(CAST(visitor_country AS STRING), '')
            )
        ) AS surrogate_key
    FROM {{ ref('_int__operations__orders_gmv__agg_daily_prep') }}
    {% if is_incremental() %}
    WHERE sys_audit_updated_on > (
        SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01 00:00:00')
        FROM {{ this }}
    )
    {% endif %}
)

SELECT
    b.*,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM base_data b
LEFT JOIN existing_data e
  ON b.surrogate_key = e.surrogate_key
WHERE
    e.sys_audit_updated_on IS NULL
    OR b.sys_audit_updated_on > e.sys_audit_updated_on
