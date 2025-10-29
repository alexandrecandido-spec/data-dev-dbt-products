SELECT
    ir.request_id,
    ss.store_id,
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
    ir.order_id,
    DATE(ir.request_created_at) as request_created_date,
    ir.invoice_type,
    ir.request_status,
    case 
        when sfc.feature_name = 'SMARTONLINE_PRODUCTION_ENVIRONMENT'
            and sfc.feature_enabled = true
            and ir.request_created_at >= sfc.sfc_created_at
            then true
        else false
    end as is_prd_environment,
    get_json_object(ir.rejected_request_reason, '$[0].error_group') AS request_error_group,
    get_json_object(ir.rejected_request_reason, '$[0].error_code') AS request_error_code,
    i.invoice_status,
    DATE(i.invoice_created_at) as invoice_created_date,
    DATE(i.invoice_authorized_at) as invoice_authorized_date,
    DATE(ii.invoice_cancelled_at) as invoice_cancelled_date,

    GREATEST(
        COALESCE(ir.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP)),
        COALESCE(ii.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP)),
        COALESCE(i.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP)),
        COALESCE(sfc.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP)),
        COALESCE(a.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP)),
        COALESCE(ss.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP))
    ) AS sys_audit_updated_on

FROM {{ ref('product__invoicing__invoice_request__event') }} ir
JOIN {{ ref('s__lifecycle__store_status__ref') }} ss
    ON ir.store_id = ss.store_id
JOIN {{ ref('s__attributes__store_core__ref') }} a
    ON ir.store_id = a.store_id
LEFT JOIN {{ ref('product__invoicing__internal_invoice__event') }} ii
    ON ir.request_id = ii.request_id
LEFT JOIN {{ ref('product__invoicing__invoice__event') }} i
    ON i.invoice_id = ii.invoice_id
LEFT JOIN {{ ref('product__invoicing__store_feature_configuration__event') }} sfc
    ON ir.store_id = sfc.store_id