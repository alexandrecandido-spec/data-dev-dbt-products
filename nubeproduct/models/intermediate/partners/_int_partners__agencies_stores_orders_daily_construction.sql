SELECT 
    PO.store_id,
    DATE(PO.completed_at) AS order_date,
    SUM(PO.total) AS gmv_local_currency_daily,
    SUM(PO.total_in_usd) AS gmv_usd_daily,
    COUNT(PO.id) AS orders_daily,
    GREATEST(MAX(PO.sys_audit_updated_on), MAX(PS.sys_audit_updated_on)) AS construction_change_timestamp,
    PS.partner_id
FROM {{ ref('company_metrics_paid_orders') }} AS PO
INNER JOIN {{ ref('partners_agencies_affiliates_stores') }} AS PS
    ON PO.store_id = PS.store_id
WHERE PO.completed_at IS NOT NULL
    AND PO.platform_type = 'on'
    AND PS.partnership_type = 'store_development'
GROUP BY 
    PO.store_id, 
    DATE(PO.completed_at),
    PS.partner_id