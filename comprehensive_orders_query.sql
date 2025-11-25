-- Query comprensiva para análisis de órdenes con toda la información solicitada
-- Incluye: store_id, order_id, date, hour, device, source, social network, province, city, 
-- province shipping, region, shipping method, free shipping, promotions, installments, 
-- payment method, payment provider, store name, success status

WITH base_orders AS (
  SELECT 
    o.store_id,
    o.id AS order_id,
    DATE(o.completed_at) AS date,
    EXTRACT(HOUR FROM o.completed_at) AS hour,
    o.device,
    o.completed_at,
    o.created_at,
    o.status,
    o.payment_status,
    o.gateway,
    o.gateway_method,
    o.gateway_integration_type,
    o.gateway_installments,
    o.shipping_method,
    o.shipping_cost,
    o.shipping_option,
    o.shipping_pickup_type,
    o.shipping_province,
    o.storefront,
    o.total,
    o.total_in_usd,
    o.currency,
    o.year_month_day_code,
    -- Indicador de éxito: orden completada y pagada, no cancelada
    CASE  
      WHEN o.status != 'cancelled' 
        AND o.payment_status = 'paid' 
        AND o.completed_at IS NOT NULL 
      THEN TRUE 
      ELSE FALSE 
    END AS is_success,
    -- Indicador de envío gratis
    CASE 
      WHEN o.shipping_cost = 0 OR o.shipping_cost IS NULL 
      THEN TRUE 
      ELSE FALSE 
    END AS is_free_shipping
  FROM {{ ref('orders__mwp_orders') }} o
  WHERE o.completed_at IS NOT NULL
),

-- Información de origen social y marketing
social_source AS (
  SELECT 
    s.order_id,
    s.utm_source,
    s.utm_medium,
    s.http_referrer,
    s.source,
    s.source_details,
    s.source_name,
    s.source_type,
    -- Clasificación de redes sociales
    CASE 
      WHEN s.source_name IN ('instagram', 'facebook', 'tiktok', 'twitter', 'pinterest', 'meta') 
      THEN s.source_name
      WHEN s.source_name = 'whatsapp' THEN 'whatsapp'
      WHEN s.http_referrer LIKE '%linkedin%' THEN 'linkedin'
      WHEN s.http_referrer LIKE '%youtube%' THEN 'youtube'
      ELSE 'other'
    END AS social_network
  FROM {{ ref('product_social_order_source') }} s
),

-- Información de la tienda y ubicación
store_info AS (
  SELECT 
    mi.store_id,
    mi.domain AS store_name,
    mi.country_code,
    mi.country_name,
    mi.base_region_name AS region,
    mi.base_state_name AS province,
    mi.base_city_name AS city,
    mi.current_segment_name,
    mi.vertical_name,
    mi.group_name AS plan
  FROM {{ ref('company_metrics_merchant_info') }} mi
),

-- Información de ubicación de envío (province shipping)
shipping_location AS (
  SELECT DISTINCT
    ls.state_code,
    ls.state_name AS shipping_province_name
  FROM {{ ref('dim_location_state') }} ls
),

-- Información de métodos de pago más detallada
payment_info AS (
  SELECT 
    o.id AS order_id,
    CASE 
      WHEN apps.handle IS NOT NULL THEN apps.handle
      WHEN o.gateway = 'testmode' THEN 'test_mode'
      ELSE o.gateway
    END AS payment_provider,
    o.gateway_method AS payment_method_detail,
    COALESCE(o.gateway_installments, 0) AS installments
  FROM {{ ref('orders__mwp_orders') }} o
  LEFT JOIN {{ source('int_moltres', 'mwp_apps') }} apps 
    ON CONCAT("app_", apps.id) = o.gateway
),

-- Información de métodos de envío más detallada  
shipping_info AS (
  SELECT 
    o.id AS order_id,
    CASE 
      WHEN sc.handle IS NOT NULL THEN sc.handle
      WHEN o.shipping_method = 'table' THEN 'custom_table'
      WHEN o.shipping_method = 'pickup' THEN 'store_pickup'
      ELSE o.shipping_method
    END AS shipping_method_name
  FROM {{ ref('orders__mwp_orders') }} o
  LEFT JOIN {{ source('int_moltres', 'mwp_shipping_carriers') }} sc 
    ON CONCAT("api_", sc.id) = o.shipping_method
),

-- Verificación de promociones aplicadas (basado en descuentos)
promotion_info AS (
  SELECT 
    o.id AS order_id,
    -- Identificar si hay promociones basándose en patrones comunes
    CASE 
      WHEN o.total < (o.total_in_usd * 0.9) THEN TRUE  -- Descuento significativo
      WHEN o.shipping_cost = 0 AND o.shipping_method != 'pickup' THEN TRUE  -- Envío gratis promocional
      ELSE FALSE
    END AS has_promotion
  FROM {{ ref('orders__mwp_orders') }} o
)

-- Query principal que combina toda la información
SELECT 
  bo.store_id,
  bo.order_id,
  bo.date,
  bo.hour,
  bo.device,
  
  -- Información de origen y marketing
  COALESCE(ss.source, 'direct') AS source,
  ss.social_network,
  
  -- Ubicación de la tienda
  si.province,
  si.city,
  si.region,
  
  -- Ubicación de envío
  COALESCE(sl.shipping_province_name, bo.shipping_province, 'Not specified') AS province_shipping,
  
  -- Información de envío
  COALESCE(shi.shipping_method_name, bo.shipping_method) AS shipping_method,
  bo.is_free_shipping,
  
  -- Información de promociones
  pi.has_promotion AS has_promotion,
  
  -- Información de pago
  COALESCE(pmi.installments, 0) AS installments,
  COALESCE(pmi.payment_method_detail, bo.gateway_method) AS payment_method,
  COALESCE(pmi.payment_provider, bo.gateway) AS payment_provider,
  
  -- Información de la tienda
  si.store_name,
  
  -- Estado de éxito
  bo.is_success,
  
  -- Campos adicionales útiles para análisis
  bo.total,
  bo.total_in_usd,
  bo.currency,
  bo.storefront,
  si.country_name AS country,
  si.current_segment_name AS store_segment,
  si.vertical_name AS store_vertical,
  bo.completed_at AS order_completed_timestamp

FROM base_orders bo
LEFT JOIN social_source ss ON bo.order_id = ss.order_id
LEFT JOIN store_info si ON bo.store_id = si.store_id
LEFT JOIN shipping_location sl ON bo.shipping_province = sl.state_code
LEFT JOIN payment_info pmi ON bo.order_id = pmi.order_id
LEFT JOIN shipping_info shi ON bo.order_id = shi.order_id
LEFT JOIN promotion_info pi ON bo.order_id = pi.order_id

-- Filtros opcionales (puedes ajustar según necesites)
WHERE bo.completed_at >= '2024-01-01'  -- Ajusta la fecha según tu necesidad
  AND bo.is_success = TRUE  -- Solo órdenes exitosas, comenta esta línea si quieres todas

ORDER BY bo.completed_at DESC;
