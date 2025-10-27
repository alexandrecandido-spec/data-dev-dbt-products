SELECT
    
    po.id as order_id,
    DATE(po.completed_at) as order_completed_date,    
    po.store_id,
    s.domain,
    s.feature_activation_date,
    s.plan_group,
    s.store_state,
    s.current_segment,
    s.country,
    s.address_state,
    s.tax_regime_code,
    s.tax_regime_name,
    s.registry_status,
    s.cert_valid,
    s.days_to_cert_expire,

    GREATEST(
        COALESCE(po.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP)),
        COALESCE(sfc.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP)),
        COALESCE(s.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP))
    ) AS sys_audit_updated_on

FROM {{ ref('company_metrics_paid_orders') }} po

JOIN {{ ref('product__invoicing__store_feature_configuration__event') }} sfc
    ON po.store_id = sfc.store_id
    AND sfc.feature_name = 'SMARTONLINE_PRODUCTION_ENVIRONMENT'
    AND sfc.feature_enabled = TRUE
    AND po.completed_at >= sfc.sfc_created_at

JOIN {{ ref('s__invoicing__store__event') }} s
    ON po.store_id = s.store_id

WHERE po.year_month_day_code >= 20250801
