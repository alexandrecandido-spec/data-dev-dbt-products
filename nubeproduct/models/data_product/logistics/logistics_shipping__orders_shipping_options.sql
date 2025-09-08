{{
    config(
        materialized='incremental',
        unique_key=['order_id'],
        incremental_strategy='merge',
        partition_by='year_month_code',
        on_schema_change='fail',
        tags=["logistics", "daily-8am"]
    )
}}

WITH existing_data AS (
    {{ get_existing_data(this, ['order_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),

db_orders AS (
    SELECT 
          fo.id as order_id
        , fo.store_id
        , fo.year_month_code
        
        , COALESCE(
              dbco.shipping_option_result
            , lsc.shipping_option_result
            , CONCAT(dbc.carrier_name, ' - ', 'Outros')
            ) AS shipping_option_result

        , COALESCE(
              dbco.carrier_name
            , lsc.carrier_name, dbc.carrier_name
            ) AS carrier_name
            
        , CASE
            WHEN dbco.id IS NOT NULL THEN NULL
            ELSE lsc.partner
            END  AS shipping_partner
            
        , COALESCE(
                dbco.shipping_service
              , lsc.service
              , 'Outros'
              ) AS shipping_service

        -- Auditoria
        , COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on
        , COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by
        , current_timestamp AS sys_audit_updated_on
        , 'data-dev-dbt-products' AS sys_audit_updated_by

    FROM 
        {{ ref('_int_logistics_shipping__filtered_orders') }} fo
        LEFT JOIN {{ ref('_int_logistics_shipping__correios_class') }} dbco 
            ON dbco.id = fo.id
        LEFT JOIN {{ ref('_int_logistics_shipping__carrier_names') }} dbc 
            ON dbc.shipping_method = fo.shipping_method
        LEFT JOIN {{ source("dp_data_manual", "logistics__shipping_classification") }} lsc 
            ON lsc.carrier_name = dbc.carrier_name 
            AND lsc.shipping_option_code = fo.shipping_option_code
        LEFT JOIN existing_data e 
            ON fo.id = e.order_id

    {% if is_incremental() %}
      WHERE fo.year_month_code >= CAST(date_format(add_months(current_date(), -2), 'yyyyMM') AS INT)
    {% endif %}
)

SELECT * FROM db_orders
