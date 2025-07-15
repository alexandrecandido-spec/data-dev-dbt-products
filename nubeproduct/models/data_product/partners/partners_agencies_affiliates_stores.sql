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
        IF(BP.store_id IS NOT NULL, TRUE, FALSE) AS block_flg,
        SI.current_segment,
        CASE 
            WHEN SI.current_segment NOT IN ('no-seller', 'struggling-seller') THEN 'Active merchants' 
            WHEN SI.current_segment IS NULL THEN 'Other'
        ELSE 'Non-active merchants' 
        END AS merchant_type,
        IF(SI.current_segment NOT IN ('no-seller', 'struggling-seller'),TRUE,FALSE) AS active_merchant_flg,
        QL.device,
        QL.new_payment_probability,
        QL.prod_cutoff,
        IF(QL.new_payment_probability >= QL.prod_cutoff,TRUE,FALSE) AS quality_lead_flg,
        CASE 
            WHEN SI.first_payment_ts < DATE('2022-06-22')
                AND SI.first_payment_ts IS NOT NULL 
            THEN TRUE
            WHEN SI.first_payment_ts >= DATE('2022-06-22') 
                AND SI.first_payment_ts IS NOT NULL 
                AND 
                    (
                        SI.churned_at_ts IS NULL 
                            OR 
                        DATE_TRUNC('MONTH', SI.first_payment_ts) < DATE_TRUNC('MONTH', SI.churned_at_ts)
                    ) 
            THEN TRUE 
        ELSE FALSE 
        END AS first_payment_flg,
        CASE 
            WHEN SI.partnership_type = 'affiliate'
            THEN 'Affiliate'
            WHEN TAB.has_partner_tag = 1 AND TAB.has_affiliate_tag = 0
            THEN 'Partner'
        ELSE 'Nuvemshop'
        END AS acquired_by,  
        SI.created_at_ts,
        SI.first_payment_ts,
        SI.churned_at_ts,
        SI.plan_id,
        OGP.grupo AS plan_group,
        OGP.namev2 AS plan_name,
        SI.partner_id,
        SI.partnership_type,
        PI.partner_code,
        PI.partner_name,
        PI.partner_country_code,
        PI.partner_created_at_ts,
        AC.mkt_exclusion,
        AC.affiliate_classification,
        AC.affiliate_tier,
        AC.affiliate_main_platform
    FROM {{ ref('_int_partners__agencies_affiliates_stores_store_info') }} AS SI
    LEFT JOIN {{ ref('_int_partners__agencies_affiliates_stores_partners_info') }} AS PI
        ON SI.partner_id = PI.partner_id
    LEFT JOIN {{ ref('_int_partners__agencies_affiliates_stores_quality_leads') }} AS QL
        ON SI.store_id = QL.store_id
    LEFT JOIN {{ ref('_int_partners__agencies_affiliates_stores_tag_acquired_by') }} AS TAB
        ON SI.store_id = TAB.store_id
    LEFT JOIN {{ ref('operations_grouping_plans') }} AS OGP
        ON SI.plan_id = OGP.plan   
    LEFT JOIN {{ ref('_int_partners__agencies_affiliates_stores_block_partner_stores') }} AS BP
        ON SI.store_id = BP.store_id
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
/*
WHERE 
    {% if not is_incremental() %}
      partner_stores.created_at_ts >= DATE '2000-01-01'
    {% endif %}
    {% if is_incremental() %}
      partner_stores.sys_audit_updated_on > (
        SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01')
        FROM {{ this }}
      )
    {% endif %}
*/