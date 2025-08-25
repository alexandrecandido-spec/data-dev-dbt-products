SELECT 
    PO.store_id,
    DATE(PO.completed_at) AS order_date,
    COALESCE(SUM(PO.total), 0) AS gmv_local_currency_daily,
    COALESCE(SUM(PO.total_in_usd), 0) AS gmv_usd_daily,
    COALESCE(COUNT(PO.id), 0) AS orders_daily,
    MAX(PO.sys_audit_updated_on) AS construction_change_timestamp
FROM {{ ref('company_metrics_paid_orders') }} AS PO
INNER JOIN {{ ref('partners_agencies_affiliates_stores') }} AS PS
    ON PO.store_id = PS.store_id
WHERE PO.completed_at IS NOT NULL
    AND PO.platform_type = 'on'
    AND PS.partnership_type = 'store_development'
GROUP BY 
    PO.store_id, 
    DATE(PO.completed_at)