SELECT
    ss.store_id,
    t.tag,
    DATE(t.created) as tag_created_date,
    DATE(sir.registry_created_at) as registry_created_date,
    DATE(sir.registry_updated_at) as registry_updated_date,
    sfc.feature_name,
    sfc.feature_enabled,
    CASE
        WHEN sfc.feature_name = 'SMARTONLINE_PRODUCTION_ENVIRONMENT'
            AND sfc.feature_enabled = true
            THEN DATE(sfc.sfc_created_at)
        ELSE NULL
    END AS feature_activation_date,
    a.domain,
    sir.legal_name,
    sir.trade_name,
    ss.current_plan_type as plan_group,
    case
        when ss.state = 0 then '0 - store ok'
        when ss.state = 1 then '1 - awaiting store payment'
        when ss.state = 2 then '2 - store admin down'
        when ss.state = 3 then '3 - store churned'
        when ss.state = 4 then '4 - test store'
        when ss.state = 5 then '5 - store on partner prep'
        else '9 - other'
    end as store_state,
    ss.current_segment,
    a.country_code as country,
    INITCAP(sir.city_name) as address_city,
    sir.state_code as address_state,
    sir.tax_regime_code,
    CASE
        WHEN sir.tax_regime_code = 1 then 'Simples Nacional'
        WHEN sir.tax_regime_code = 4 then 'MEI - Micro Empreendedor Individual'
        WHEN sir.tax_regime_code IS NOT NULL then 'Other'
        ELSE sir.tax_regime_code
    END AS tax_regime_name,
    sir.registry_status,
    CASE
        WHEN current_date BETWEEN DATE(sir.cert_validity_from) AND DATE(sir.cert_validity_to) THEN TRUE 
        WHEN current_date > DATE(sir.cert_validity_to) THEN FALSE
        ELSE NULL
    END AS cert_valid,
    DATE_DIFF(DATE(sir.cert_validity_to), current_date) as days_to_cert_expire,

    GREATEST(
        COALESCE(t.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP)),
        COALESCE(sir.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP)),
        COALESCE(sfc.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP)),
        COALESCE(a.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP)),
        COALESCE(ss.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP))
    ) AS sys_audit_updated_on

FROM {{ source('int_moltres', 'mwp_tags') }} t

LEFT JOIN {{ ref('product__invoicing__store_invoice_registry__event') }} sir
    ON t.related_id = sir.store_id

JOIN {{ ref('s__lifecycle__store_status__ref') }} ss
    ON t.related_id = ss.store_id

JOIN {{ ref('s__attributes__store_core__ref') }} a
    ON t.related_id = a.store_id

LEFT JOIN {{ ref('product__invoicing__store_feature_configuration__event') }} sfc
    ON t.related_id = sfc.store_id

WHERE t.tag = 'new-admin-invoices' AND t.type = 'store'