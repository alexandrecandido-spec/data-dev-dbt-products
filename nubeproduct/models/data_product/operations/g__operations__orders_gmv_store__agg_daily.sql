{{ config(
    materialized        = "incremental",
    incremental_strategy= "merge",
    partition_by        = "year_month_day_code",
    unique_key          = [
        "country", "vertical", "province", "city", "region",
        "business_size", "max_seller_segment", "current_seller_segment", "historical_seller_segment",
        "current_plan", "historical_plan", "current_bu", "historical_bu",
        "date", "year_month_day_code", "mes", "platform_type", "storefront", "device",
        "payment_provider", "payment_method", "shipping_method", "shipping_province",
        "gateway_installments", "source_name", "source_group", "google_subchannel", "traffic_type", "is_end_user", "visitor_country"
    ],
    on_schema_change    = "fail",
    tags                = ["daily-9am"]
) }}

WITH existing_data AS (
    {{ get_existing_data(this, [
        "country", "vertical", "province", "city", "region",
        "business_size", "max_seller_segment", "current_seller_segment", "historical_seller_segment",
        "current_plan", "historical_plan", "current_bu", "historical_bu",
        "date", "year_month_day_code", "mes", "platform_type", "storefront", "device",
        "payment_provider", "payment_method", "shipping_method", "shipping_province",
        "gateway_installments", "source_name", "source_group", "google_subchannel", "traffic_type", "is_end_user", "visitor_country",
        "sys_audit_created_on", "sys_audit_created_by", "sys_audit_updated_on"
    ]) }}
),

base_data AS (
    SELECT *
    FROM {{ ref('_int__operations__orders_gmv_store__agg_daily_prep') }}
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
  USING (
      country, vertical, province, city, region,
      business_size, max_seller_segment, current_seller_segment, historical_seller_segment,
      current_plan, historical_plan, current_bu, historical_bu,
      date, year_month_day_code, mes, platform_type, storefront, device,
      payment_provider, payment_method, shipping_method, shipping_province,
      gateway_installments, source_name, source_group, google_subchannel, traffic_type, is_end_user, visitor_country
  )
WHERE
    e.sys_audit_updated_on IS NULL
    OR b.sys_audit_updated_on > e.sys_audit_updated_on
