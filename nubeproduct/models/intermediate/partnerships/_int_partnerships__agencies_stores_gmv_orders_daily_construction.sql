SELECT 
    PO.store_id,
    DATE(PO.date) AS order_date,
    COALESCE(SUM(PO.gmv), 0) AS gmv_local_currency_daily,
    COALESCE(SUM(PO.gmv_usd), 0) AS gmv_usd_daily,
    COALESCE(SUM(PO.orders), 0) AS orders_daily,
    MAX(PO.sys_audit_updated_on) AS construction_change_timestamp
FROM {{ ref('g__operations__orders_gmv_store__agg_daily') }} AS PO
INNER JOIN {{ ref('_int_partnerships__partners_stores__table_merchant_domain') }} AS PS
    ON PO.store_id = PS.store_id
WHERE PO.platform_type = 'on'
    AND PS.partnership_type = 'store_development'
GROUP BY 
    PO.store_id, 
    DATE(PO.date)
