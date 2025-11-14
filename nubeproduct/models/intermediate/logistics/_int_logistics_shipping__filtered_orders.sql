SELECT
      id
    , store_id
    , shipping_method
    , shipping_option_code
    , shipping_option
    , year_month_code
FROM 
    {{ source('int_stg_orders', 'mwp_orders') }}
    WHERE 1=1
        AND year_month_code >= CAST(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), 730), 'yyyyMM') AS INT)
        AND shipping_method LIKE 'api_%'