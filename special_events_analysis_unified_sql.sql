-- =============================================================================
-- 🎯 SPECIAL EVENTS ANALYSIS - QUERY UNIFICADA PARA SQL EDITOR
-- =============================================================================
-- 
-- Adaptada del notebook Databricks para ejecutar directamente en SQL editor
-- Incluye toda la lógica: merchant info, events, orders, promotions, tagging
-- 
-- CONFIGURACIÓN HARDCODEADA (modificar aquí según necesidad):
-- - PW_DAYS_BACK = 2 (días hacia atrás para Pre-Week)
-- - COUNTRIES = ['AR'] (países a procesar)
-- - Eventos desde 2021-01-01
-- - Orders entre $0 - $10,000 USD
-- - Excluye storefronts 'permalink'
-- - Excluye tiendas bloqueadas con tags SRE
-- 
-- =============================================================================

WITH

-- =============================================================================
-- 🏢 1. MERCHANT INFO MODULAR (5 MÓDULOS CONSOLIDADOS)
-- =============================================================================

-- 📊 1.1. BASE STORE INFORMATION
base_stores_info AS (
  SELECT 
    id AS store_id,
    created_at,
    country AS country_code,
    domain,
    first_payment,
    current_segment,
    email_marketing,
    plan AS plan_id_nk,
    main_user_id,
    partner_id,
    partnership_type
  FROM hive_metastore.moltres.mwp_store_info
  WHERE state != 4 
    AND country IN ('AR')  -- HARDCODED: modificar según países
),

store_names AS (
  SELECT 
    store_id,
    store_name
  FROM (
    SELECT 
      ss.store_id,
      NULLIF(TRIM(i18n.name), '') AS store_name,
      ROW_NUMBER() OVER (PARTITION BY ss.store_id ORDER BY i18n.id DESC) AS rnk
    FROM hive_metastore.moltres.mwp_store_settings ss
    LEFT JOIN hive_metastore.moltres.mwp_store_settings_i18n i18n
      ON ss.id = i18n.store_setting_id
  ) ranked
  WHERE rnk = 1
),

contacts_social AS (
  SELECT
    store_id,
    phone,
    whatsapp_phone_number AS whatsapp,
    CASE
      WHEN owner_phone_number LIKE '+%' THEN owner_phone_number
      WHEN owner_phone_country IS NOT NULL 
        OR owner_phone_area IS NOT NULL
        OR owner_phone_number IS NOT NULL
      THEN CONCAT(
        '+',
        COALESCE(owner_phone_country, ''),
        COALESCE(owner_phone_area, ''),
        COALESCE(owner_phone_number, '')
      )
      ELSE NULL
    END AS owner_phone,
    NULLIF(TRIM(instagram), '') AS instagram,
    NULLIF(TRIM(facebook), '') AS facebook,
    business_id
  FROM hive_metastore.moltres.mwp_store_settings
),

user_emails AS (
  SELECT
    store_id,
    user_email,
    id AS main_user_id
  FROM (
    SELECT
      store_id,
      user_email,
      id,
      ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY id DESC) AS rn
    FROM hive_metastore.moltres.wp_users
  ) ranked
  WHERE rn = 1
),

base_store_complete AS (
  SELECT 
    bs.store_id,
    bs.created_at,
    sn.store_name,
    bs.domain,
    
    -- Contacts  
    COALESCE(ue.user_email, bs.email_marketing) AS email_contact,
    cs.phone,
    cs.whatsapp,
    cs.owner_phone,
    
    -- Basic store data
    bs.country_code,
    bs.current_segment,
    bs.first_payment,
    bs.plan_id_nk,
    bs.partner_id,
    bs.partnership_type,
    
    -- User info  
    COALESCE(ue.main_user_id, bs.main_user_id) AS main_user_id

  FROM base_stores_info bs
  LEFT JOIN store_names sn ON bs.store_id = sn.store_id
  LEFT JOIN contacts_social cs ON bs.store_id = cs.store_id  
  LEFT JOIN user_emails ue ON bs.store_id = ue.store_id
),

-- 🌍 1.2. LOCATION INFORMATION
shipping_locations AS (
  SELECT
    CAST(storeid AS BIGINT) AS store_id,
    address.country.code AS country_code,
    address.province.code AS state_code,
    address.zipcode AS zipcode
  FROM hive_metastore.shipping.locations
  WHERE address IS NOT NULL 
    AND chosenasdefaultat IS NOT NULL 
    AND deletedat IS NULL 
    AND isdraft = false
    AND address.country.code IN ('AR')  -- HARDCODED: modificar según países
),

zipcode_cities AS (
  SELECT zipcode, city_id, 'AR' AS country_code 
  FROM hive_metastore.moltres.mwp_zipcodes_ar
  
  UNION ALL
  
  SELECT zipcode, city_id, 'MX' AS country_code 
  FROM hive_metastore.moltres.mwp_zipcodes_mx
  
  UNION ALL
  
  SELECT 
    cep AS zipcode, 
    CAST(city_id AS BIGINT) AS city_id, 
    'BR' AS country_code 
  FROM (
    SELECT 
      cep, 
      city_id, 
      ROW_NUMBER() OVER(PARTITION BY cep ORDER BY sys_audit_updated_on DESC) AS rnk 
    FROM hive_metastore.moltres.ceps
  ) ranked_ceps
  WHERE rnk = 1
),

states_with_regions AS (
  SELECT 
    a.code AS state_code,
    a.name AS state_name,
    a.country AS country_code,
    CASE
      -- Argentina regions  
      WHEN a.country = 'AR' AND a.code IN ('J','M','D') THEN 'Cuyo'
      WHEN a.country = 'AR' AND a.code IN ('BX','C') THEN 'Gran Buenos Aires + Ciudad Autónoma de Buenos Aires'
      WHEN a.country = 'AR' AND a.code IN ('P','H','N','W') THEN 'Noreste Argentino'
      WHEN a.country = 'AR' AND a.code IN ('Y','A','K','F','T','G') THEN 'Noroeste Argentino'
      WHEN a.country = 'AR' AND a.code IN ('B','X','L','S','E') THEN 'Pampeana'
      WHEN a.country = 'AR' AND a.code IN ('Q','R','U','Z','V') THEN 'Patagonia'
      -- Mexico regions
      WHEN a.country = 'MX' AND a.code IN ('AGU','GUA','QUE','SLP','ZAC') THEN 'Bajio'
      WHEN a.country = 'MX' AND a.code IN ('CMX','MEX','MOR','HID','PUE','TLA') THEN 'Centro'
      WHEN a.country = 'MX' AND a.code IN ('COA','NLE','TAM') THEN 'Norte'
      -- Brasil regions  
      WHEN a.country = 'BR' AND a.code IN ('MT','MS','GO','DF') THEN 'Centro-oeste'
      WHEN a.country = 'BR' AND a.code IN ('BA','SE','AL','PE','PB','RN','CE','MA','PI') THEN 'Nordeste'
      WHEN a.country = 'BR' AND a.code IN ('RO','RR','AM','AP','PA','AC','TO') THEN 'Norte'
      WHEN a.country = 'BR' AND a.code IN ('MG','ES','RJ','SP') THEN 'Sudeste'
      WHEN a.country = 'BR' AND a.code IN ('PR','SC','RS') THEN 'Sul'
      ELSE 'Other'
    END AS region_name
  FROM hive_metastore.moltres.mwp_provinces a
  WHERE a.country IN ('AR')  -- HARDCODED: modificar según países
),

cities AS (
  SELECT 
    id AS city_id_nk,
    name AS city_name,
    province_id AS state_id,
    'AR' AS country_code
  FROM hive_metastore.moltres.mwp_cities_ar
  
  UNION ALL
  
  SELECT 
    id AS city_id_nk,
    name AS city_name,
    province_id AS state_id,
    'MX' AS country_code
  FROM hive_metastore.moltres.mwp_cities_mx
  
  UNION ALL
  
  SELECT 
    id AS city_id_nk,
    name AS city_name,
    province_id AS state_id,
    'BR' AS country_code
  FROM hive_metastore.moltres.cidades
),

location_complete AS (
  SELECT 
    bs.store_id,
    COALESCE(sl.country_code, 'AR') AS country_code,  -- HARDCODED: default país
    sw.region_name AS base_region_name,
    sw.state_name AS base_state_name,
    ci.city_name AS base_city_name

  FROM base_stores_info bs
  LEFT JOIN shipping_locations sl ON bs.store_id = sl.store_id
  LEFT JOIN zipcode_cities zc ON sl.zipcode = zc.zipcode AND sl.country_code = zc.country_code
  LEFT JOIN states_with_regions sw ON sl.country_code = sw.country_code AND sl.state_code = sw.state_code
  LEFT JOIN cities ci ON zc.country_code = ci.country_code AND zc.city_id = ci.city_id_nk
),

-- 🏷️ 1.3. BUSINESS CLASSIFICATION
latest_vertifier AS (
  SELECT 
    store_id,
    CASE 
      WHEN vertifier IS NULL OR vertifier IN ('', 'unknown') THEN 'Not Informed'
      ELSE vertifier 
    END AS vertifier_classification
  FROM (
    SELECT 
      CAST(storeid AS BIGINT) AS store_id,
      CAST(primary.name AS STRING) AS vertifier,
      ROW_NUMBER() OVER(PARTITION BY storeid ORDER BY createdat DESC) AS rnk
    FROM hive_metastore.antifraud_service.vertifier_store_inferences
  ) ranked_vertifier
  WHERE rnk = 1
),

store_settings_info AS (
  SELECT
    store_id,
    type AS manual_type,
    business_size
  FROM hive_metastore.moltres.mwp_store_settings
),

segment_classification AS (
  SELECT
    bs.store_id,
    CASE
      WHEN bs.current_segment IS NULL 
        OR LOWER(TRIM(bs.current_segment)) IN ('not informed','not_informed')
      THEN 'Not Informed'
      WHEN LOWER(TRIM(bs.current_segment)) IN ('no-seller','struggling-seller')
      THEN bs.current_segment
      WHEN LOWER(TRIM(bs.current_segment)) IN ('emerging','emerging-seller')
      THEN 'emerging-seller'  
      WHEN LOWER(TRIM(bs.current_segment)) IN ('growing','growing-seller')
      THEN 'growing-seller'
      WHEN LOWER(TRIM(bs.current_segment)) IN ('established','established-seller')
      THEN 'established-seller'
      WHEN LOWER(TRIM(bs.current_segment)) IN ('scaling','scaling-seller')
      THEN 'scaling-seller'
      ELSE 'Not Informed'
    END AS current_segment_name
  FROM base_stores_info bs
),

business_complete AS (
  SELECT 
    bs.store_id,
    sc.current_segment_name,
    CASE 
      WHEN ss.manual_type IS NULL THEN lv.vertifier_classification 
      ELSE ss.manual_type 
    END AS vertical_name,
    COALESCE(ss.business_size, 'Not Informed') AS business_size_name

  FROM base_stores_info bs
  LEFT JOIN segment_classification sc ON bs.store_id = sc.store_id
  LEFT JOIN latest_vertifier lv ON bs.store_id = lv.store_id
  LEFT JOIN store_settings_info ss ON bs.store_id = ss.store_id
),

-- 💼 1.4. PLAN GROUPS CLASSIFICATION
plans_info AS (
  SELECT 
    pc.id AS plan_countries_id,
    pc.plan AS plan_id,
    pc.country AS country_code,
    COALESCE(pi.desc, pi.ipn, 'unknown') AS nice_name,
    COALESCE(mpg.grupo, 'unknown') AS grupo,
    COALESCE(mpg.namev2, 'unknown') AS namev2
  FROM hive_metastore.moltres.mwp_plans_countries pc
  LEFT JOIN hive_metastore.moltres.mwp_plans pi ON pc.plan = pi.id
  LEFT JOIN hive_metastore.data_manual.operations__grouping_plans_aux mpg 
    ON pc.id = mpg.plan
),

plan_groups AS (
  SELECT
    bs.store_id,
    COALESCE(
      NULLIF(pi.grupo, 'unknown'),
      CASE
        WHEN LOWER(pi.nice_name) LIKE '%plan-a%' THEN 'plan-a'
        WHEN LOWER(pi.nice_name) LIKE '%plan-b%' THEN 'plan-b'
        WHEN LOWER(pi.nice_name) LIKE '%plan-c%' THEN 'plan-c'
        WHEN LOWER(pi.nice_name) LIKE '%plan-free%' THEN 'freemium'
        WHEN LOWER(pi.nice_name) LIKE '%plan-basico%' OR LOWER(pi.nice_name) LIKE '%plano-basico%' THEN 'lojinha'
        WHEN LOWER(pi.nice_name) LIKE '%enterprise%' OR LOWER(pi.nice_name) LIKE '%empresarial%' THEN 'enterprise'
        ELSE 'unknown'
      END
    ) AS group_name,
    CASE 
      WHEN pi.plan_countries_id IN (681,682,683,684) THEN 0
      WHEN pi.plan_countries_id <= 2575 THEN 1
      ELSE 0
    END AS before_freemium_launch
    
  FROM base_stores_info bs
  LEFT JOIN plans_info pi ON bs.plan_id_nk = pi.plan_countries_id
  WHERE NOT (COALESCE(pi.grupo, 'unknown') IN ('test_broken', 'no-stores') OR pi.plan_countries_id IN (20, 21))
),

plans_complete AS (
  SELECT 
    store_id,
    COALESCE(group_name, 'unknown') AS group_name,
    before_freemium_launch
  FROM plan_groups
),

-- 🎯 1.5. MARKETING ATTRIBUTION
partners_info AS (
  SELECT 
    mp.id AS partner_id,
    mp.code AS partner_code,
    mp.name AS partner_name
  FROM hive_metastore.ecosystem.mwp_partners mp
),

latest_attribution AS (
  SELECT
    store_id,
    source AS mkt_source_last_click,
    medium AS mkt_medium_last_click,
    campaign AS mkt_campaign_last_click
  FROM (
    SELECT
      store_id,
      source,
      medium,
      campaign,
      ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY id DESC) AS rn
    FROM hive_metastore.moltres.mwp_attribution
    WHERE store_id IS NOT NULL
  ) ranked
  WHERE rn = 1
),

attribution_complete AS (
  SELECT 
    bs.store_id,
    pi.partner_code,
    la.mkt_source_last_click,
    CASE
      WHEN pi.partner_code IS NOT NULL THEN 'Partners'
      WHEN la.mkt_source_last_click IS NOT NULL THEN la.mkt_source_last_click
      ELSE 'Direct'
    END AS team_last_click,
    CASE
      WHEN pi.partner_code IS NOT NULL THEN 'Partners'
      WHEN la.mkt_medium_last_click IS NOT NULL THEN la.mkt_medium_last_click
      ELSE 'Direct'
    END AS subteam_last_click

  FROM base_stores_info bs
  LEFT JOIN partners_info pi ON bs.partner_id = pi.partner_id
  LEFT JOIN latest_attribution la ON bs.store_id = la.store_id
),

-- 🏢 MERCHANT COMPLETE (UNIÓN DE TODOS LOS MÓDULOS)
merchant_complete AS (
  SELECT 
    -- Base info
    b.store_id,
    b.created_at,
    b.store_name,
    b.domain,
    b.email_contact,
    b.phone,
    b.whatsapp,
    b.owner_phone,
    b.country_code,
    b.current_segment,
    b.first_payment,
    b.plan_id_nk,
    b.partner_id,
    b.partnership_type,
    b.main_user_id,
    
    -- Location info
    l.base_region_name,
    l.base_state_name,
    l.base_city_name,
    
    -- Business info
    bc.current_segment_name,
    bc.vertical_name,
    bc.business_size_name,
    
    -- Plans info
    p.group_name,
    p.before_freemium_launch,
    
    -- Attribution info
    a.partner_code,
    a.mkt_source_last_click,
    a.team_last_click,
    a.subteam_last_click
    
  FROM base_store_complete b
  LEFT JOIN location_complete l ON b.store_id = l.store_id
  LEFT JOIN business_complete bc ON b.store_id = bc.store_id
  LEFT JOIN plans_complete p ON b.store_id = p.store_id
  LEFT JOIN attribution_complete a ON b.store_id = a.store_id
),

-- =============================================================================
-- 📅 2. EVENTS & WINDOWS (CONFIGURABLES)
-- =============================================================================

events_base AS (
  SELECT
    name,
    country,
    CAST(start_date AS TIMESTAMP) AS start_local,
    CAST(end_date AS TIMESTAMP) AS end_local
  FROM hive_metastore.moltres.mwp_special_date
  WHERE country IN ('AR')  -- HARDCODED: modificar según países
    AND start_date >= TIMESTAMP('2021-01-01T00:00:00')  -- HARDCODED: fecha mínima
    AND lower(name) NOT LIKE '%test%'  -- HARDCODED: exclude test events
    -- HARDCODED: excluded events
    AND lower(name) NOT IN ('fonsopalooza', 'fonsopalooza2', 'test_event_2023', 'prueba_hot_sale')
),

prep_events AS (
  SELECT
    name,
    country,
    start_local,
    end_local,
    HOUR(start_local) AS start_hour,
    DATE(start_local) AS start_day,
    DATE(date_trunc('week', start_local)) AS monday_of_event_week,
    DATE_ADD(DATE(start_local), -2) AS pw_start_day  -- HARDCODED: PW_DAYS_BACK = 2
  FROM events_base
),

event_windows_local AS (
  SELECT
    name AS event_name,
    country,
    start_local,
    end_local,
    monday_of_event_week,
    pw_start_day,
    start_hour,
    start_day
  FROM prep_events
),

-- =============================================================================
-- 🛒 3. ORDERS SCOPED (OPTIMIZADO)
-- =============================================================================

blocked_stores AS (
  SELECT related_id AS store_id 
  FROM hive_metastore.moltres.mwp_tags 
  WHERE type = 'store' 
    AND tag IN ('sre-block-store-429', 'sre-block-store-404')  -- HARDCODED: blocked tags
),

orders_scoped AS (
  SELECT 
    o.id AS order_pk,
    o.order_id,
    o.store_id,
    LOWER(o.contact_email) AS contact_email,
    o.currency,
    o.total,
    o.total_in_usd,
    o.storefront,
    o.status,
    o.device_type,
    o.payment_status,
    o.gateway,
    o.shipping_method,
    o.shipping_cost,
    o.shipping_option,
    o.shipping_pickup_type,
    o.shipping_province,
    o.gateway_integration_type,
    o.gateway_installments,
    o.gateway_method,
    o.app_id,
    o.completed_at,
    o.created_at,
    
    -- Paid timestamp exacto
    pl.paid_at,
    
    -- Products quantity
    COALESCE(pq.products_quantity, 0) AS products_quantity,
    
    -- Country from merchant
    mm.country_code AS country_code

  FROM hive_metastore.orders.mwp_orders o
  INNER JOIN merchant_complete mm ON mm.store_id = o.store_id
  LEFT JOIN blocked_stores bs ON bs.store_id = o.store_id
  
  -- Payment date optimizada
  LEFT JOIN (
    SELECT 
      order_id, 
      MAX(happened_at) AS paid_at
    FROM hive_metastore.orders.mwp_orders_logging
    WHERE data_2 = 'paid'
    GROUP BY order_id
  ) pl ON pl.order_id = o.id
  
  -- Products quantity
  LEFT JOIN (
    SELECT
      order_id,
      SUM(quantity) AS products_quantity
    FROM hive_metastore.orders.mwp_order_products
    WHERE deleted_at IS NULL
    GROUP BY order_id
  ) pq ON pq.order_id = o.id

  WHERE bs.store_id IS NULL
    AND o.completed_at IS NOT NULL
    AND o.order_id IS NOT NULL
    -- HARDCODED: order filters
    AND o.total_in_usd BETWEEN 0 AND 10000
    AND o.storefront NOT IN ('permalink')
    -- Date filter - ventanas específicas por evento
    AND EXISTS (
      SELECT 1 FROM event_windows_local e
      WHERE mm.country_code = e.country
        AND o.completed_at >= to_utc_timestamp(e.pw_start_day, 
          CASE e.country
            WHEN 'AR' THEN 'America/Argentina/Buenos_Aires'
            WHEN 'BR' THEN 'America/Sao_Paulo'
            WHEN 'MX' THEN 'America/Mexico_City'
            WHEN 'CO' THEN 'America/Bogota'
            WHEN 'CL' THEN 'America/Santiago'
            ELSE 'UTC'
          END)
        AND o.completed_at <= to_utc_timestamp(e.end_local,
          CASE e.country
            WHEN 'AR' THEN 'America/Argentina/Buenos_Aires'
            WHEN 'BR' THEN 'America/Sao_Paulo'
            WHEN 'MX' THEN 'America/Mexico_City'
            WHEN 'CO' THEN 'America/Bogota'
            WHEN 'CL' THEN 'America/Santiago'
            ELSE 'UTC'
          END)
    )
),

-- =============================================================================
-- 🎁 4. PROMOCIONES OPTIMIZADAS (DATABRICKS)
-- =============================================================================

promotions_data AS (
  SELECT
    os.order_pk,
    
    -- Flags de promociones esenciales
    CASE WHEN mo.coupon_id IS NOT NULL THEN 1 ELSE 0 END AS orders_coupon,
    
    CASE WHEN mo.promotional_discount_id IS NOT NULL THEN 1 ELSE 0 END AS orders_promo_price,
    
    CASE WHEN mo.shipping_cost = 0 OR mo.shipping_cost IS NULL THEN 1 ELSE 0 END AS orders_free_shipping,
    
    -- Flag combinado
    CASE WHEN (
      CASE WHEN mo.coupon_id IS NOT NULL THEN 1 ELSE 0 END +
      CASE WHEN mo.promotional_discount_id IS NOT NULL THEN 1 ELSE 0 END +
      CASE WHEN mo.shipping_cost = 0 OR mo.shipping_cost IS NULL THEN 1 ELSE 0 END
    ) > 0 THEN 1 ELSE 0 END AS orders_with_any_promotion,
    
    -- Descuentos simplificados
    0 AS descuento_pct,
    
    -- Promotion type simplificado
    'N/A' AS promotion_type

  FROM orders_scoped os
  LEFT JOIN hive_metastore.orders.mwp_orders mo ON mo.id = os.order_pk
),

-- =============================================================================
-- 🎯 5. EVENT TAGGING & WINDOWS (PW vs MAIN)
-- =============================================================================

-- Solo eventos reales
real_events AS (
  SELECT *
  FROM event_windows_local 
  WHERE event_name NOT LIKE 'BOUNDS_%'
),

-- JOIN específico por ventanas exactas
orders_with_events AS (
  SELECT
    o.*,
    e.event_name,
    e.start_local,
    e.end_local,
    e.start_hour,
    e.start_day,
    e.pw_start_day,
    e.monday_of_event_week,
    
    -- Convertir a local para cálculos de tagging
    CASE
      WHEN o.country_code = 'AR' THEN from_utc_timestamp(o.completed_at, 'America/Argentina/Buenos_Aires')
      WHEN o.country_code = 'BR' THEN from_utc_timestamp(o.completed_at, 'America/Sao_Paulo')
      WHEN o.country_code = 'MX' THEN from_utc_timestamp(o.completed_at, 'America/Mexico_City')
      WHEN o.country_code = 'CO' THEN from_utc_timestamp(o.completed_at, 'America/Bogota')
      WHEN o.country_code = 'CL' THEN from_utc_timestamp(o.completed_at, 'America/Santiago')
    END AS completed_at_local,
    
    -- JOIN con promociones
    COALESCE(p.orders_coupon, 0) AS orders_coupon,
    COALESCE(p.orders_promo_price, 0) AS orders_promo_price, 
    COALESCE(p.orders_free_shipping, 0) AS orders_free_shipping,
    COALESCE(p.orders_with_any_promotion, 0) AS orders_with_any_promotion,
    p.promotion_type,
    p.descuento_pct
    
  FROM orders_scoped o
  INNER JOIN real_events e ON o.country_code = e.country
    AND o.completed_at >= to_utc_timestamp(e.pw_start_day, 
      CASE e.country
        WHEN 'AR' THEN 'America/Argentina/Buenos_Aires'
        WHEN 'BR' THEN 'America/Sao_Paulo'
        WHEN 'MX' THEN 'America/Mexico_City'
        WHEN 'CO' THEN 'America/Bogota'
        WHEN 'CL' THEN 'America/Santiago'
        ELSE 'UTC'
      END)
    AND o.completed_at <= to_utc_timestamp(e.end_local,
      CASE e.country
        WHEN 'AR' THEN 'America/Argentina/Buenos_Aires'
        WHEN 'BR' THEN 'America/Sao_Paulo'
        WHEN 'MX' THEN 'America/Mexico_City'
        WHEN 'CO' THEN 'America/Bogota'
        WHEN 'CL' THEN 'America/Santiago'
        ELSE 'UTC'
      END)
  LEFT JOIN promotions_data p ON o.order_pk = p.order_pk
),

-- Cálculos de tagging consolidados
tagged_orders AS (
  SELECT
    o.*,
    DATE_TRUNC('hour', o.completed_at_local) AS completed_hour,
    
    -- Cálculos de días consolidados
    CASE
      WHEN DATE(o.completed_at_local) = o.start_day AND HOUR(o.completed_at_local) < o.start_hour THEN -1
      WHEN DATE(o.completed_at_local) = o.start_day AND HOUR(o.completed_at_local) >= o.start_hour THEN 0
      WHEN DATE(o.completed_at_local) < o.start_day THEN DATEDIFF(DATE(o.completed_at_local), o.start_day) - 1
      ELSE DATEDIFF(DATE(o.completed_at_local), o.start_day)
    END AS special_date_day
    
  FROM orders_with_events o
),

-- Resultado final con campos derivados
final_tagged AS (
  SELECT
    t.order_pk,
    t.order_id,
    t.store_id,
    t.country_code,
    t.completed_at,
    t.completed_at_local,
    t.completed_hour,
    t.event_name,
    t.special_date_day,
    
    -- Columnas de órdenes
    t.contact_email, t.currency, t.total, t.total_in_usd, t.storefront, t.status, t.device_type,
    t.payment_status, t.gateway, t.shipping_method, t.shipping_province, t.gateway_installments,
    t.gateway_method, t.created_at, t.paid_at, t.products_quantity,
    
    -- Métricas de promociones
    t.orders_coupon, t.orders_promo_price, t.orders_free_shipping, t.orders_with_any_promotion,
    t.promotion_type, t.descuento_pct,
    
    -- Campos derivados esenciales
    CASE 
      WHEN t.special_date_day BETWEEN -2 AND -1  -- HARDCODED: PW_DAYS_BACK = 2
      THEN CONCAT(t.event_name, '_pw')
      ELSE t.event_name
    END AS special_date_name,
    
    -- Short name simplificado
    CASE
      WHEN lower(t.event_name) LIKE '%hotsale%' THEN 'HOTSALE'
      WHEN lower(t.event_name) LIKE '%cybermonday%' THEN 'CYBERMONDAY'  
      WHEN lower(t.event_name) LIKE '%blackfriday%' THEN 'BLACKFRIDAY'
      WHEN lower(t.event_name) LIKE '%buenfin%' THEN 'BUENFIN'
      ELSE upper(t.event_name)
    END AS short_core,
    
    -- PW flag
    CASE 
      WHEN t.special_date_day BETWEEN -2 AND -1 THEN 1  -- HARDCODED: PW_DAYS_BACK = 2
      ELSE 0 
    END AS is_pw,
    
    -- Fechas simplificadas
    CASE
      WHEN t.special_date_day BETWEEN -2 AND -1  -- HARDCODED: PW_DAYS_BACK = 2
        THEN date_format(t.pw_start_day, 'yyyy-MM-dd')
      ELSE date_format(DATE(t.start_local), 'yyyy-MM-dd')
    END AS special_date_date_start,
    
    CASE
      WHEN t.special_date_day BETWEEN -2 AND -1  -- HARDCODED: PW_DAYS_BACK = 2
        THEN date_format(DATE(t.start_local), 'yyyy-MM-dd')
      ELSE date_format(DATE(t.end_local), 'yyyy-MM-dd')
    END AS special_date_date_end,
    
    date_format(t.completed_hour, 'yyyy-MM-dd') AS special_date_date,
    
    -- Day name simplificado
    CASE dayofweek(t.completed_hour)
      WHEN 1 THEN 'domingo'   WHEN 2 THEN 'lunes'     WHEN 3 THEN 'martes'
      WHEN 4 THEN 'miércoles' WHEN 5 THEN 'jueves'    WHEN 6 THEN 'viernes'
      WHEN 7 THEN 'sábado'
    END AS special_date_day_name
    
  FROM tagged_orders t
  WHERE t.special_date_day BETWEEN -2 AND -1 OR t.special_date_day >= 0  -- HARDCODED: ventana PW + MAIN
),

-- =============================================================================
-- 🔗 6. UNIONES FINALES Y ENRIQUECIMIENTO
-- =============================================================================

apps AS (
  SELECT id, handle 
  FROM hive_metastore.moltres.mwp_apps
),

shipping_carriers AS (
  SELECT id, app_id 
  FROM hive_metastore.moltres.mwp_shipping_carriers
),

cartera_success AS (
  SELECT DISTINCT 
    CAST(store_id AS BIGINT) AS store_id, 
    TRUE AS is_cartera_success
  FROM hive_metastore.data_midmarket.midmarket_success_stores mss
  WHERE mss.in_portfolio = TRUE
),

-- =============================================================================
-- 🎯 RESULTADO FINAL ENRIQUECIDO
-- =============================================================================

enriched_final AS (
  SELECT
    t.order_pk,
    t.order_id,
    t.store_id,
    
    -- Merchant info completa
    m.store_name,
    m.domain,
    m.email_contact,
    m.phone,
    m.owner_phone,
    m.partner_code,
    
    -- Geographic info
    m.country_code AS country,
    m.base_region_name AS region,
    m.base_state_name AS province,
    CASE
      WHEN m.country_code = 'AR' AND UPPER(m.base_state_name) IN (
        'CABA','CAPITAL FEDERAL','CIUDAD AUTÓNOMA DE BUENOS AIRES','CIUDAD AUTONOMA DE BUENOS AIRES'
      ) THEN 'caba + gba'
      WHEN m.country_code = 'AR' AND UPPER(m.base_state_name) = 'BUENOS AIRES' THEN 'buenos aires'
      WHEN m.country_code = 'AR' AND UPPER(m.base_state_name) = 'CÓRDOBA'     THEN 'cordoba'
      WHEN m.country_code = 'AR' AND UPPER(m.base_state_name) = 'MENDOZA'     THEN 'mendoza'
      WHEN m.country_code = 'AR' AND UPPER(m.base_state_name) = 'SANTA FE'    THEN 'santa fe'
      WHEN m.country_code = 'AR' THEN 'resto del pais'
      ELSE NULL
    END AS province_grouping,
    m.base_city_name AS city,
    
    -- Business classification  
    m.current_segment_name AS segment,
    m.business_size_name AS business_size,
    m.group_name AS plan_group,
    COALESCE(cs.is_cartera_success, FALSE) AS is_cartera_success,
    
    -- Vertical classification corregida
    m.vertical_name AS vertical_vertifier,
    CASE
      WHEN LOWER(m.vertical_name) IN ('clothing_accesories','clothing','jewelry','fashion','apparel','accessories','moda') THEN 'clothing'
      WHEN LOWER(m.vertical_name) IN ('gifts','bookstore_graphic','books','education','art','stationery','libros') THEN 'books'
      WHEN LOWER(m.vertical_name) IN ('electronics_it','electronics','technology','computers','phones','electro','tecnologia') THEN 'electronics_it'
      WHEN LOWER(m.vertical_name) IN ('health_beauty','beauty','cosmetics','health','wellness','belleza','salud') THEN 'health_beauty'
      WHEN LOWER(m.vertical_name) IN ('food_drinks','food','drinks','beverages','restaurant','alimentos','bebidas','comida') THEN 'food_drinks'
      WHEN LOWER(m.vertical_name) IN ('home_garden','home','garden','furniture','decor','hogar','jardin','muebles') THEN 'home_garden'
      WHEN LOWER(m.vertical_name) IN ('sports','sport','deportes','fitness','gym') THEN 'sports'
      WHEN LOWER(m.vertical_name) IN ('automotive','auto','cars','vehiculos','repuestos') THEN 'automotive'
      WHEN m.vertical_name IS NULL OR LOWER(m.vertical_name) = 'not informed' THEN 'other'
      ELSE 'other'
    END AS vertical_grouping,
    
    -- Store dates & aging
    m.created_at AS store_created_at,
    CAST(FLOOR(months_between(current_date(), CAST(m.created_at AS DATE)) / 12) AS INT) AS aging_years,
    CASE WHEN m.first_payment IS NOT NULL THEN 1 ELSE 0 END AS first_payment_flag,
    
    -- Order details
    t.contact_email,
    t.currency,
    t.total,
    t.total_in_usd,
    t.storefront,
    t.status,
    -- Device classification corregida
    CASE
      WHEN COALESCE(t.device_type,'Desktop') IN ('phone','tablet') THEN 'Mobile'
      ELSE REPLACE(COALESCE(t.device_type,'Desktop'),'computer','Desktop')
    END AS device,
    t.payment_status,
    
    -- Gateway normalization
    CASE 
      WHEN a.handle IS NOT NULL THEN a.handle
      WHEN t.gateway = 'testmode' THEN 'custom'
      ELSE t.gateway
    END AS gateway_provider_norm,
    
    CASE
      WHEN LOWER(COALESCE(a.handle, t.gateway, '')) RLIKE '(mercado.?pago|mp)' THEN 'Mercado Pago'
      WHEN LOWER(COALESCE(a.handle, t.gateway, '')) RLIKE '(pago-nube)' THEN 'Pago Nube'
      WHEN LOWER(COALESCE(a.handle, t.gateway, '')) RLIKE '(pagos-personalizados)' THEN 'Efectivo / Transferencia'
      ELSE 'Other'
    END AS gateway_provider_grouping,
    
    t.gateway_installments,
    t.gateway_method,
    
    -- Shipping normalization
    t.shipping_province,
    CASE 
      WHEN a2.handle IS NOT NULL THEN a2.handle
      WHEN t.shipping_method = 'table' THEN 'custom'
      ELSE t.shipping_method
    END AS shipping_method_norm,
    
    -- Timestamps
    t.completed_at,
    t.created_at,
    t.paid_at,
    t.completed_at_local,
    CAST(DATE(t.completed_hour) AS DATE) AS completed_at_date,
    t.completed_hour AS completed_hour_local,
    
    -- Special date info
    t.event_name,
    t.special_date_name,
    CASE 
      WHEN t.is_pw = 1 THEN CONCAT(t.short_core, '_PW') 
      ELSE t.short_core 
    END AS special_date_name_short,
    t.special_date_day,
    t.special_date_day_name,
    HOUR(t.completed_hour) AS special_date_hour,
    t.country_code AS special_date_country,
    t.special_date_date_start,
    t.special_date_date_end,
    t.special_date_date,
    t.is_pw,
    
    -- Promociones
    COALESCE(t.orders_coupon, 0) AS orders_coupon,
    COALESCE(t.orders_promo_price, 0) AS orders_promo_price, 
    COALESCE(t.orders_free_shipping, 0) AS orders_free_shipping,
    COALESCE(t.orders_with_any_promotion, 0) AS orders_with_any_promotion,
    COALESCE(t.orders_with_any_promotion, 0) AS orders_promotions,
    t.promotion_type,
    t.descuento_pct,
    t.descuento_pct AS descuento_avg_pct,
    
    -- Products & metrics
    COALESCE(t.products_quantity, 0) AS products_quantity,
    
    -- Métricas por orden (paid-based)
    CASE 
      WHEN t.paid_at IS NOT NULL AND t.status <> 'cancelled' 
      THEN t.total 
      ELSE 0 
    END AS gmv,
    
    CASE 
      WHEN t.paid_at IS NOT NULL AND t.status <> 'cancelled' 
      THEN 1 
      ELSE 0 
    END AS orders,
    
    -- Attribution
    m.team_last_click,
    m.subteam_last_click
    
  FROM final_tagged t
  LEFT JOIN merchant_complete m ON t.store_id = m.store_id
  LEFT JOIN cartera_success cs ON t.store_id = cs.store_id
  LEFT JOIN apps a ON CONCAT('app_', a.id) = t.gateway
  LEFT JOIN shipping_carriers sca ON CONCAT('api_', sca.id) = t.shipping_method
  LEFT JOIN apps a2 ON a2.id = sca.app_id
)

-- =============================================================================
-- 🎯 SELECT FINAL - COLUMNAS OPTIMIZADAS PARA TABLEAU
-- =============================================================================

SELECT
  -- Identifiers
  order_id, store_id, 
  
  -- Store info
  store_name, domain, email_contact, phone, partner_code,
  
  -- Geography
  country, region, province, province_grouping, city,
  
  -- Business
  segment, business_size, plan_group, is_cartera_success,
  vertical_vertifier, vertical_grouping,
  
  -- Store lifecycle
  store_created_at, aging_years, first_payment_flag,
  
  -- Order details
  currency, total, total_in_usd, storefront, status, device,
  payment_status, gateway_provider_norm, gateway_provider_grouping,
  gateway_installments, shipping_method_norm, shipping_province,
  
  -- Timestamps
  completed_at, paid_at, completed_at_local, completed_at_date,
  completed_hour_local,
  
  -- Special date
  event_name, special_date_name, special_date_name_short,
  special_date_day, special_date_day_name, special_date_hour,
  special_date_country, special_date_date_start, special_date_date_end,
  special_date_date, is_pw,
  
  -- Promotions
  orders_coupon, orders_promo_price, orders_free_shipping,
  orders_with_any_promotion, orders_promotions, promotion_type,
  descuento_pct, descuento_avg_pct,
  
  -- Metrics & products
  products_quantity, gmv, orders,
  
  -- Attribution
  team_last_click, subteam_last_click

FROM enriched_final
ORDER BY special_date_name, special_date_day, completed_hour_local;

-- =============================================================================
-- 🎯 COMENTARIOS DE CONFIGURACIÓN PARA MODIFICAR:
-- =============================================================================
--
-- Para adaptar esta query, modifica las siguientes líneas HARDCODED:
--
-- 1. PAÍSES (líneas marcadas con "HARDCODED: modificar según países"):
--    - Cambiar 'AR' por ['AR', 'MX', 'BR', etc.]
--
-- 2. PW_DAYS_BACK (líneas marcadas con "HARDCODED: PW_DAYS_BACK = 2"):
--    - Cambiar -2 por el número de días deseado (ej: -7 para 7 días)
--
-- 3. FILTROS DE EVENTOS (líneas marcadas con "HARDCODED:"):
--    - Fecha mínima: cambiar '2021-01-01'
--    - Eventos excluidos: agregar/quitar de la lista
--
-- 4. FILTROS DE ÓRDENES (líneas marcadas con "HARDCODED: order filters"):
--    - Rangos USD: cambiar BETWEEN 0 AND 10000
--    - Storefronts excluidos: cambiar 'permalink'
--
-- 5. TAGS BLOQUEADAS (líneas marcadas con "HARDCODED: blocked tags"):
--    - Modificar lista de tags SRE
--
-- =============================================================================
