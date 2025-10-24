{{ 
    config(
        materialized = 'incremental',
        incremental_strategy = 'merge',
        unique_key = ['store_id'],
        on_schema_change = 'fail',
        tags = ['daily-10am']
) }}

WITH existing_data AS (
    {{ get_existing_data(this, ['store_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),
partner_stores AS    
(
    SELECT
        SI.store_id,
        SI.main_user_id,
        SI.domain,
        SI.country_code,    
        SI.state,
        SI.business_unit,
        SI.block_flg,
        SI.current_segment, --VARIAR
        SI.merchant_type,
        SI.active_merchant_flg,
        SI.device,
        SI.predicted_prob,
        SI.prod_cutoff,
        SI.quality_lead_flg,
        SI.first_payment_flg,
        SI.churned_flg,
        SI.first_seller_flg,
        SI.acquired_by,  
        SI.created_at,
        SI.first_payment,
        SI.first_seller_at,
        SI.churned_at,
        SI.payment_lifecycle_status,
        SI.plan_id,
        SI.plan_group,
        SI.plan_name,
        SI.started_as,
        SI.first_plan_id,
        SI.first_plan_group,
        SI.first_plan_name,
        SI.partner_id,
        SI.partnership_type,
        DATE(SI.store_info_change_timestamp) AS dp_change_timestamp
    FROM {{ ref('_int_partnerships__partners_stores__info') }} AS SI
)
SELECT 
    partner_stores.* EXCEPT(dp_change_timestamp),
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM partner_stores
LEFT JOIN existing_data e
    ON partner_stores.store_id = e.store_id
    {% if is_incremental() %}
WHERE    
      partner_stores.dp_change_timestamp > 
        (
            SELECT COALESCE(MAX(sys_audit_updated_on), DATE '1900-01-01')
            FROM {{ this }}
        )
    {% endif %}