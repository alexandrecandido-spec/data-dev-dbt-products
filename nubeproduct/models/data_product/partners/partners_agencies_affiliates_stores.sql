{{ 
    config(
        materialized = 'incremental',
        incremental_strategy = 'merge',
        unique_key = ['store_id'],
        on_schema_change = 'fail',
        tags = ['partners', 'daily-9am']
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
        FSD.first_seller_at,
        SI.churned_at,
        SI.plan_id,
        OGP.grupo AS plan_group,
        OGP.namev2 AS plan_name,
        SI.partner_id,
        SI.partnership_type,
        PI.partner_code,
        PI.partner_name,
        PI.partner_country_code,
        PI.partner_created_at_ts,
        PI.partner_email,
        PI.partner_phone_number,
        PU.partner_utm_campaign,
        PU.partner_utm_source,
        PU.partner_utm_medium,
        PU.partner_utm_content,
        AC.mkt_exclusion,
        AC.affiliate_classification,
        AC.affiliate_tier,
        AC.affiliate_main_platform
    FROM {{ ref('_int_partners__agencies_affiliates_stores_store_info') }} AS SI
    LEFT JOIN {{ ref('_int_partners__agencies_affiliates_stores_partners_info') }} AS PI
        ON SI.partner_id = PI.partner_id
    LEFT JOIN {{ ref('operations_grouping_plans') }} AS OGP
        ON SI.plan_id = OGP.plan   
    LEFT JOIN {{ ref('_int_partners__agencies_affiliates_stores_affiliates_classification') }} AS AC
        ON PI.partner_code = AC.partner_code
            AND PI.partner_country_code = AC.affiliate_country
    LEFT JOIN {{ ref('_int_partners__agencies_affiliates_stores_partner_utm') }} AS PU
        ON SI.partner_id = PU.partner_id
    LEFT JOIN {{ ref('marketing_first_seller_date') }} AS FSD  
        ON SI.store_id = FSD.store_id
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