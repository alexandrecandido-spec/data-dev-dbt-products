{{ 
    config(
        materialized = 'incremental',
        incremental_strategy = 'merge',
        unique_key = ['store_id'],
        on_schema_change = 'fail',
        tags = ['daily-9am']
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
        SI.block_flg,
        SI.current_segment,
        SI.merchant_type,
        SI.active_merchant_flg,
        SI.device,
        SI.new_payment_probability,
        SI.prod_cutoff,
        SI.quality_lead_flg,
        SI.first_payment_flg,
        SI.acquired_by,  
        SI.created_at,
        SI.first_payment,
        SI.first_seller_at,
        SI.churned_at,
        SI.plan_id,
        SI.plan_group,
        SI.plan_name,
        SI.partner_id,
        SI.partnership_type,
        PI.partner_code,
        PI.partner_name,
        PI.partner_country_code,
        PI.partner_created_at,
        PI.partner_email,
        PI.partner_phone_number,
        PI.partner_utm_campaign,
        PI.partner_utm_source,
        PI.partner_utm_medium,
        PI.partner_utm_content,
        AC.mkt_exclusion,
        AC.affiliate_classification,
        AC.affiliate_tier,
        AC.affiliate_main_platform
    FROM {{ ref('_int_partners__agencies_affiliates_stores_store_info') }} AS SI
    LEFT JOIN {{ ref('_int_partners__agencies_affiliates_stores_partners_info') }} AS PI
        ON SI.partner_id = PI.partner_id
    LEFT JOIN {{ ref('_int_partners__agencies_affiliates_stores_affiliates_classification') }} AS AC
        ON PI.partner_code = AC.partner_code
            AND PI.partner_country_code = AC.affiliate_country
)
SELECT 
    partner_stores.*,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM partner_stores
LEFT JOIN existing_data e
    ON partner_stores.store_id = e.store_id