-- _int__product__shipping__orders_and_gmv

WITH shipping_carriers as (
    SELECT
    CONCAT('api_', CAST(sc.id as STRING)) AS carrier_id,
    a.handle AS carrier
    FROM {{ source('int_moltres', 'mwp_shipping_carriers') }} sc
    JOIN {{ source('int_moltres', 'mwp_apps') }} a
        ON sc.app_id = a.id
)

SELECT
    po.store_id,
    po.country as store_country,
    ss.current_plan_type as plan_group,
    ss.current_segment as segment,
    sc.vertical_name as vertical,
    DATE(po.completed_at) as order_completed_at,
    io.shipping_country_code,
    io.shipping_country_name,
    io.is_international_shipping,
    sd.is_same_delivered_status,
    CASE 
	    WHEN po.shipping_method LIKE 'api_%' THEN concat('app - ', c.carrier)
	    WHEN po.shipping_method LIKE '%table%' AND po.shipping_pickup_type = 'ship' THEN 'personalizado: envio'
	    WHEN po.shipping_method LIKE '%table%' AND po.shipping_pickup_type = 'pickup' THEN 'personalizado: retiro'
        WHEN (po.shipping_method LIKE 'branch') THEN 'retiro tienda fisica'
        WHEN (po.shipping_method LIKE 'pickup-point') THEN 'puntos de retiro (new)'
	    WHEN po.shipping_method LIKE 'draft' THEN 'draft order'
	    WHEN po.shipping_method IS NULL THEN 'without shipping data'
	    WHEN po.shipping_method = 'multiple' THEN 'multiples (multicd)'
	    WHEN po.shipping_method = 'fallback' THEN 'fallback'
	    ELSE concat('core - ', po.shipping_method) 
    END AS shipping_method,
    CASE 
	    WHEN po.shipping_method LIKE 'api_%' THEN 'app integration'
	    WHEN po.shipping_method LIKE '%table%' AND po.shipping_pickup_type = 'ship' THEN 'personalizado: envio'
	    WHEN po.shipping_method LIKE '%table%' AND po.shipping_pickup_type = 'pickup' THEN 'personalizado: retiro'
        WHEN (po.shipping_method LIKE 'branch') THEN 'retiro tienda fisica'
        WHEN (po.shipping_method LIKE 'pickup-point') THEN 'puntos de retiro (new)'
	    WHEN po.shipping_method LIKE 'draft' THEN 'draft order'
	    WHEN po.shipping_method IS NULL THEN 'without shipping data'
	    WHEN po.shipping_method = 'multiple' THEN 'multiples (multicd)'
	    WHEN po.shipping_method = 'fallback' THEN 'fallback'
	    ELSE concat('core - ', po.shipping_method) 
    END AS integration,
    SUM(po.total_in_usd) as total_in_usd,
    COUNT(DISTINCT po.id) as total_orders

FROM {{ ref('company_metrics_paid_orders') }} po

JOIN {{ ref('s__lifecycle__store_status__ref') }} ss
    ON po.store_id = ss.store_id

JOIN {{ ref('s__attributes__store_core__ref') }} sc
    ON po.store_id = sc.store_id

LEFT JOIN shipping_carriers c
    ON po.shipping_method = c.carrier_id

LEFT JOIN {{ ref('_int__product__shipping__international_orders') }} io
    ON po.id = io.order_id

LEFT JOIN {{ ref('_int__product__shipping__same_delivered_status') }} sd
    ON po.id = sd.order_id_

WHERE 1=1
    AND DATE(po.completed_at) > DATE(DATE_ADD(MONTH, -13, current_date))
    AND ss.state <> 4

GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12