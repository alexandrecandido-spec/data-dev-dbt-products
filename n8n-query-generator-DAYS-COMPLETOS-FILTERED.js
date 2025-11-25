// n8n Code node (JavaScript)
// Generador EXACTO de queries que funcionan - COMPARACIÓN TEMPORAL JUSTA
// CORREGIDO: Solo días completos (0,1,2,3) - Día 0 desde 20:00

// =======================
// ⚙️ CONFIG
// =======================
const CFG = {
  CURRENT_EVENT: "cybermonday-2025",
  LAST_EVENT: "cybermonday-2024",
  
  // Tablas exactas
  TABLES: {
    CORE_ACTUAL: "data_products_dev.testing_marketing.special_events_actual",
    CORE_HISTORICO: "data_products_dev.testing_marketing.special_events_historico",
    SESSIONS_ACTUAL: "data_products_dev.testing_marketing.special_events_sessions_actual", 
    SESSIONS_HISTORICO: "data_products_dev.testing_marketing.special_events_sessions_historico",
    PRODUCTS_ACTUAL: "data_products_dev.testing_marketing.special_events_products_actual",
    PRODUCTS_HISTORICO: "data_products_dev.testing_marketing.special_events_products_name_historico"
  }
};

// Minificar SQL
const minify = (s) =>
  s.replace(/--.*$/gm, "")
   .replace(/\/\*[\s\S]*?\*\//g, "")
   .replace(/\s+/g, " ")
   .replace(/\s*,\s*/g, ", ")
   .replace(/\s*\(\s*/g, "(")
   .replace(/\s*\)\s*/g, ")")
   .trim();

// =======================
// 🔧 RELATIVE TIME LOGIC HELPER - DÍAS COMPLETOS
// =======================

// Helper function to generate relative time logic for any data source - SOLO DÍAS COMPLETOS
const getRelativeTimeLogic = (dataSource = "CORE") => {
  const actualTable = dataSource === "CORE" ? CFG.TABLES.CORE_ACTUAL : 
                     dataSource === "SESSIONS" ? CFG.TABLES.SESSIONS_ACTUAL : 
                     CFG.TABLES.PRODUCTS_ACTUAL;
  const historicoTable = dataSource === "CORE" ? CFG.TABLES.CORE_HISTORICO : 
                        dataSource === "SESSIONS" ? CFG.TABLES.SESSIONS_HISTORICO : 
                        CFG.TABLES.PRODUCTS_HISTORICO;
  
  return `
events_config AS (
  SELECT '${CFG.CURRENT_EVENT}' AS current_event, '${CFG.LAST_EVENT}' AS last_event
),
all_data AS (
  SELECT * FROM ${actualTable} UNION ALL SELECT * FROM ${historicoTable}
),
two_events AS (
  SELECT cd.* FROM all_data cd CROSS JOIN events_config ec
  WHERE cd.special_date_name IN (ec.current_event, ec.last_event)
),
-- 🔧 CALCULAR ÚLTIMO DÍA COMPLETO del evento actual
current_event_max_day AS (
  SELECT MAX(special_date_day) AS max_day_current
  FROM two_events te CROSS JOIN events_config ec
  WHERE te.special_date_name = ec.current_event
),
current_event_max AS (
  SELECT 
    cemd.max_day_current,
    MAX(te.special_date_hour) AS max_hour_current
  FROM two_events te 
  CROSS JOIN events_config ec
  CROSS JOIN current_event_max_day cemd
  WHERE te.special_date_name = ec.current_event
    AND te.special_date_day = cemd.max_day_current
  GROUP BY cemd.max_day_current
),
-- 🔧 DETERMINAR días completos: Si la hora máxima del último día < 23, ese día no está completo
complete_days_limit AS (
  SELECT 
    CASE 
      WHEN max_hour_current < 23 THEN max_day_current - 1  -- Día incompleto, usar día anterior
      ELSE max_day_current  -- Día completo hasta las 23:xx
    END AS last_complete_day
  FROM current_event_max
),
-- 🔧 FILTRO DE DÍAS COMPLETOS: día 0 desde 20:00, días 1,2,3+ completos
filtered_events AS (
  SELECT te.*
  FROM two_events te 
  CROSS JOIN complete_days_limit cdl
  WHERE (
    -- Día 0: Solo desde las 20:00 en adelante
    (te.special_date_day = 0 AND te.special_date_hour >= 20) OR
    -- Días 1, 2, 3+: Completos pero solo hasta el último día completo
    (te.special_date_day >= 1 AND te.special_date_day <= cdl.last_complete_day)
  )
),
with_relative_hours AS (
  SELECT fe.*, (fe.special_date_day * 24 + fe.special_date_hour) AS absolute_hour FROM filtered_events fe
),
with_starts AS (
  SELECT wh.*, MIN(absolute_hour) OVER (PARTITION BY special_date_name) AS start_hour FROM with_relative_hours wh
),
with_rel AS (
  SELECT ws.*, (ws.absolute_hour - ws.start_hour) AS rel_hour FROM with_starts ws
),
current_event_limit AS (
  SELECT MAX(rel_hour) AS rel_hour_limit FROM with_rel wr CROSS JOIN events_config ec
  WHERE wr.special_date_name = ec.current_event
)`;
};

// =======================
// 🔧 OLD LOGIC HELPER - DÍAS COMPLETOS (SOLO para Shares Analysis)
// =======================

const getOldTimeLogic = (dataSource = "CORE") => {
  const actualTable = dataSource === "CORE" ? CFG.TABLES.CORE_ACTUAL : 
                     dataSource === "SESSIONS" ? CFG.TABLES.SESSIONS_ACTUAL : 
                     CFG.TABLES.PRODUCTS_ACTUAL;
  const historicoTable = dataSource === "CORE" ? CFG.TABLES.CORE_HISTORICO : 
                        dataSource === "SESSIONS" ? CFG.TABLES.SESSIONS_HISTORICO : 
                        CFG.TABLES.PRODUCTS_HISTORICO;
  
  return `
events_config AS (
  SELECT '${CFG.CURRENT_EVENT}' AS current_event, '${CFG.LAST_EVENT}' AS last_event
),
all_data AS (
  SELECT * FROM ${actualTable} UNION ALL SELECT * FROM ${historicoTable}
),
-- 🔧 CALCULAR ÚLTIMO DÍA COMPLETO del evento actual
current_event_max_day AS (
  SELECT MAX(special_date_day) AS max_day_current
  FROM all_data ad CROSS JOIN events_config ec
  WHERE ad.special_date_name = ec.current_event
),
current_event_max AS (
  SELECT 
    cemd.max_day_current,
    MAX(ad.special_date_hour) AS max_hour_current
  FROM all_data ad 
  CROSS JOIN events_config ec
  CROSS JOIN current_event_max_day cemd
  WHERE ad.special_date_name = ec.current_event
    AND ad.special_date_day = cemd.max_day_current
  GROUP BY cemd.max_day_current
),
-- 🔧 DETERMINAR días completos
complete_days_limit AS (
  SELECT 
    CASE 
      WHEN max_hour_current < 23 THEN max_day_current - 1
      ELSE max_day_current
    END AS last_complete_day
  FROM current_event_max
),
current_event_limit AS (
  SELECT 
    last_complete_day AS max_day, 
    23 AS max_hour  -- Hasta las 23:xx del último día completo
  FROM complete_days_limit
)`;
};

// =======================
// 📊 EXACT QUERY GENERATORS - DÍAS COMPLETOS FILTERED
// =======================

// 1. GENERAL METRICS (CORE - DÍAS COMPLETOS)
const generateGeneralMetrics = () => `
WITH ${getRelativeTimeLogic("CORE")},
core_data AS (
  SELECT wr.*, ec.current_event, ec.last_event
  FROM with_rel wr
  CROSS JOIN current_event_limit cel
  CROSS JOIN events_config ec
  WHERE wr.special_date_name IN (ec.current_event, ec.last_event)
    AND wr.rel_hour <= cel.rel_hour_limit
)

SELECT 
  'General Metrics' AS section,
  SUM(CASE WHEN special_date_name = current_event THEN orders ELSE 0 END) AS current_orders,
  SUM(CASE WHEN special_date_name = current_event THEN gmv ELSE 0 END) AS current_gmv,
  SUM(CASE WHEN special_date_name = current_event THEN products_quantity ELSE 0 END) AS current_products,
  SUM(CASE WHEN special_date_name = last_event THEN orders ELSE 0 END) AS last_orders,
  SUM(CASE WHEN special_date_name = last_event THEN gmv ELSE 0 END) AS last_gmv,
  SUM(CASE WHEN special_date_name = last_event THEN products_quantity ELSE 0 END) AS last_products,
  ROUND((SUM(CASE WHEN special_date_name = current_event THEN orders ELSE 0 END) - 
         SUM(CASE WHEN special_date_name = last_event THEN orders ELSE 0 END)) * 100.0 / 
        NULLIF(SUM(CASE WHEN special_date_name = last_event THEN orders ELSE 0 END), 0), 2) AS orders_change_pct,
  ROUND((SUM(CASE WHEN special_date_name = current_event THEN gmv ELSE 0 END) - 
         SUM(CASE WHEN special_date_name = last_event THEN gmv ELSE 0 END)) * 100.0 / 
        NULLIF(SUM(CASE WHEN special_date_name = last_event THEN gmv ELSE 0 END), 0), 2) AS gmv_change_pct,
  ROUND((SUM(CASE WHEN special_date_name = current_event THEN products_quantity ELSE 0 END) - 
         SUM(CASE WHEN special_date_name = last_event THEN products_quantity ELSE 0 END)) * 100.0 / 
        NULLIF(SUM(CASE WHEN special_date_name = last_event THEN products_quantity ELSE 0 END), 0), 2) AS products_change_pct,
  MAX(completed_at_local) AS last_updated,
  MAX(current_event) AS compared_current_event,
  MAX(last_event) AS compared_last_event
FROM core_data`;

// 2A. ACTIVE STORES (CORE - DÍAS COMPLETOS)
const generateActiveStores = () => `
WITH ${getRelativeTimeLogic("CORE")},
core_data AS (
  SELECT 
    wr.special_date_name, wr.store_id,
    ec.current_event, ec.last_event
  FROM with_rel wr
  CROSS JOIN current_event_limit cel
  CROSS JOIN events_config ec
  WHERE wr.special_date_name IN (ec.current_event, ec.last_event)
    AND wr.rel_hour <= cel.rel_hour_limit
),
stores_totals AS (
  SELECT 
    COUNT(DISTINCT CASE WHEN special_date_name = current_event THEN store_id END) AS active_stores_actual,
    COUNT(DISTINCT CASE WHEN special_date_name = last_event THEN store_id END) AS active_stores_last_event,
    MAX(current_event) AS current_event,
    MAX(last_event) AS last_event
  FROM core_data
)

SELECT 
  'Active Stores Comparison' AS metric_category,
  active_stores_actual,
  active_stores_last_event,
  ROUND((active_stores_actual - active_stores_last_event) * 100.0 / NULLIF(active_stores_last_event, 0), 2) AS change_pct
FROM stores_totals`;

// 2B. BUSINESS UNIT (CORE - DÍAS COMPLETOS)
const generateBusinessUnit = () => `
WITH ${getRelativeTimeLogic("CORE")},
core_data AS (
  SELECT 
    wr.special_date_name, wr.store_id, wr.business_unit,
    ec.current_event, ec.last_event
  FROM with_rel wr
  CROSS JOIN current_event_limit cel
  CROSS JOIN events_config ec
  WHERE wr.special_date_name IN (ec.current_event, ec.last_event)
    AND wr.business_unit IS NOT NULL
    AND wr.rel_hour <= cel.rel_hour_limit
)

SELECT 
  business_unit,
  COUNT(DISTINCT CASE WHEN special_date_name = current_event THEN store_id END) AS stores_actual,
  ROUND(COUNT(DISTINCT CASE WHEN special_date_name = current_event THEN store_id END) * 100.0 / 
        SUM(COUNT(DISTINCT CASE WHEN special_date_name = current_event THEN store_id END)) OVER (), 1) AS percentage_of_total,
  COUNT(DISTINCT CASE WHEN special_date_name = last_event THEN store_id END) AS stores_last_event,
  ROUND((COUNT(DISTINCT CASE WHEN special_date_name = current_event THEN store_id END) - 
         COUNT(DISTINCT CASE WHEN special_date_name = last_event THEN store_id END)) * 100.0 / 
        NULLIF(COUNT(DISTINCT CASE WHEN special_date_name = last_event THEN store_id END), 0), 2) AS change_pct
FROM core_data
GROUP BY business_unit
ORDER BY business_unit`;

// 2C. STORE AGE (CORE - DÍAS COMPLETOS)
const generateStoreAge = () => `
WITH ${getRelativeTimeLogic("CORE")},
core_data AS (
  SELECT 
    wr.store_id, wr.aging_years,
    ec.current_event
  FROM with_rel wr
  CROSS JOIN current_event_limit cel
  CROSS JOIN events_config ec
  WHERE wr.special_date_name = ec.current_event
    AND wr.aging_years IS NOT NULL
    AND wr.rel_hour <= cel.rel_hour_limit
)

SELECT 
  aging_group,
  COUNT(DISTINCT store_id) AS stores_count,
  ROUND(COUNT(DISTINCT store_id) * 100.0 / SUM(COUNT(DISTINCT store_id)) OVER (), 1) AS percentage_of_total
FROM (
  SELECT 
    store_id,
    CASE 
      WHEN aging_years < 1 THEN '<1 año'
      WHEN aging_years >= 1 AND aging_years < 2 THEN '1-2 años'
      WHEN aging_years >= 2 AND aging_years < 4 THEN '2-4 años'
      WHEN aging_years >= 4 AND aging_years < 6 THEN '4-6 años'
      WHEN aging_years >= 6 THEN '>6 años'
      ELSE 'No informado'
    END AS aging_group
  FROM core_data
) aged_stores
GROUP BY aging_group
ORDER BY 
  CASE aging_group
    WHEN '<1 año' THEN 1
    WHEN '1-2 años' THEN 2
    WHEN '2-4 años' THEN 3
    WHEN '4-6 años' THEN 4
    WHEN '>6 años' THEN 5
    ELSE 6
  END`;

// 3. CONSUMERS (CORE - DÍAS COMPLETOS)
const generateConsumers = () => `
WITH ${getRelativeTimeLogic("CORE")},
core_data AS (
  SELECT 
    wr.special_date_name, wr.contact_email,
    ec.current_event, ec.last_event
  FROM with_rel wr
  CROSS JOIN current_event_limit cel
  CROSS JOIN events_config ec
  WHERE wr.special_date_name IN (ec.current_event, ec.last_event)
    AND wr.contact_email IS NOT NULL
    AND wr.rel_hour <= cel.rel_hour_limit
),
consumers_totals AS (
  SELECT 
    COUNT(DISTINCT CASE WHEN special_date_name = current_event THEN contact_email END) AS consumers_total_actual,
    COUNT(DISTINCT CASE WHEN special_date_name = last_event THEN contact_email END) AS consumers_totales_last_event
  FROM core_data
),
new_consumers AS (
  SELECT 
    COUNT(DISTINCT current_consumers.contact_email) AS new_consumers_actual_vs_last_event
  FROM (
    SELECT DISTINCT contact_email 
    FROM core_data 
    WHERE special_date_name = (SELECT current_event FROM core_data LIMIT 1)
  ) current_consumers
  LEFT JOIN (
    SELECT DISTINCT contact_email 
    FROM core_data 
    WHERE special_date_name = (SELECT last_event FROM core_data LIMIT 1)
  ) last_consumers ON current_consumers.contact_email = last_consumers.contact_email
  WHERE last_consumers.contact_email IS NULL
)

SELECT 
  'Consumers Comparison' AS metric_category,
  ct.consumers_total_actual,
  ct.consumers_totales_last_event,
  ROUND((ct.consumers_total_actual - ct.consumers_totales_last_event) * 100.0 / NULLIF(ct.consumers_totales_last_event, 0), 2) AS pct_change,
  nc.new_consumers_actual_vs_last_event
FROM consumers_totals ct
CROSS JOIN new_consumers nc`;

// 4. SHARES ANALYSIS (CORE - OLD LOGIC PARA PERFORMANCE + DÍAS COMPLETOS) 🔧 
const generateShares = () => `
WITH ${getOldTimeLogic("CORE")},
core_data AS (
  SELECT 
    cd.special_date_name, cd.vertical_grouping, cd.gateway_provider_grouping, cd.shipping_method_grouping,
    cd.shipping_province, cd.country, cd.gateway_installments, cd.Order_Source, cd.Social_Network,
    cd.business_unit, cd.team_last_click, cd.gmv, cd.orders,
    ec.current_event, ec.last_event,
    CASE
      WHEN cd.shipping_province IS NULL THEN 'Other'
      WHEN cd.country = 'AR' AND (
        UPPER(cd.shipping_province) = 'CAPITAL FEDERAL' OR 
        UPPER(cd.shipping_province) = 'GRAN BUENOS AIRES' OR
        UPPER(cd.shipping_province) IN ('CABA','CIUDAD AUTÓNOMA DE BUENOS AIRES','CIUDAD AUTONOMA DE BUENOS AIRES')
      ) THEN 'CABA y GBA'
      WHEN cd.country = 'AR' AND (
        UPPER(cd.shipping_province) = 'CÓRDOBA' OR 
        UPPER(cd.shipping_province) = 'CORDOBA'
      ) THEN 'Córdoba'
      WHEN cd.country = 'AR' AND (
        UPPER(cd.shipping_province) = 'SANTA FÉ' OR 
        UPPER(cd.shipping_province) = 'SANTA FE'
      ) THEN 'Santa Fé'
      WHEN cd.country = 'AR' AND (
        UPPER(cd.shipping_province) = 'BUENOS AIRES' OR 
        UPPER(cd.shipping_province) = 'BUENOS AIRES'
      ) THEN 'Buenos Aires'
      WHEN cd.country = 'AR' AND UPPER(cd.shipping_province) = 'MENDOZA' THEN 'Mendoza'
      ELSE 'Other'
    END AS shipping_province_grouping
  FROM all_data cd
  CROSS JOIN events_config ec
  CROSS JOIN current_event_limit cel
  WHERE cd.special_date_name IN (ec.current_event, ec.last_event)
    AND (
      -- 🔧 FILTRO DÍAS COMPLETOS: día 0 desde 20:00, días completos hasta max_day
      (cd.special_date_day = 0 AND cd.special_date_hour >= 20) OR
      (cd.special_date_day >= 1 AND cd.special_date_day < cel.max_day) OR 
      (cd.special_date_day = cel.max_day AND cd.special_date_hour <= cel.max_hour)
    )
),
event_totals AS (
  SELECT 
    special_date_name,
    SUM(gmv) AS total_gmv,
    SUM(orders) AS total_orders
  FROM core_data
  GROUP BY special_date_name
),
all_dimensions AS (
  SELECT 
    special_date_name AS event_actual_or_last,
    'vertical_grouping' AS dimensions,
    vertical_grouping AS valores_dimensions,
    SUM(gmv) AS gmv,
    SUM(orders) AS orders
  FROM core_data
  WHERE vertical_grouping IS NOT NULL
  GROUP BY special_date_name, vertical_grouping
  
  UNION ALL
  
  SELECT 
    special_date_name AS event_actual_or_last,
    'payment_method_grouping' AS dimensions,
    gateway_provider_grouping AS valores_dimensions,
    SUM(gmv) AS gmv,
    SUM(orders) AS orders
  FROM core_data
  WHERE gateway_provider_grouping IS NOT NULL
  GROUP BY special_date_name, gateway_provider_grouping
  
  UNION ALL
  
  SELECT 
    special_date_name AS event_actual_or_last,
    'shipping_method_grouping' AS dimensions,
    shipping_method_grouping AS valores_dimensions,
    SUM(gmv) AS gmv,
    SUM(orders) AS orders
  FROM core_data
  WHERE shipping_method_grouping IS NOT NULL
  GROUP BY special_date_name, shipping_method_grouping
  
  UNION ALL
  
  SELECT 
    special_date_name AS event_actual_or_last,
    'shipping_province_grouping' AS dimensions,
    shipping_province_grouping AS valores_dimensions,
    SUM(gmv) AS gmv,
    SUM(orders) AS orders
  FROM core_data
  WHERE shipping_province_grouping IS NOT NULL
  GROUP BY special_date_name, shipping_province_grouping
  
  UNION ALL
  
  SELECT 
    special_date_name AS event_actual_or_last,
    'installments_grouping' AS dimensions,
    CASE 
      WHEN gateway_installments = 1 THEN '1 cuota'
      WHEN gateway_installments = 3 THEN '3 cuotas'
      WHEN gateway_installments = 6 THEN '6 cuotas'
      WHEN gateway_installments = 12 THEN '12 cuotas'
      WHEN gateway_installments IS NULL THEN 'Sin cuotas'
      ELSE 'Otras cuotas'
    END AS valores_dimensions,
    SUM(gmv) AS gmv,
    SUM(orders) AS orders
  FROM core_data
  GROUP BY special_date_name, 
    CASE 
      WHEN gateway_installments = 1 THEN '1 cuota'
      WHEN gateway_installments = 3 THEN '3 cuotas'
      WHEN gateway_installments = 6 THEN '6 cuotas'
      WHEN gateway_installments = 12 THEN '12 cuotas'
      WHEN gateway_installments IS NULL THEN 'Sin cuotas'
      ELSE 'Otras cuotas'
    END
  
  UNION ALL
  
  SELECT 
    special_date_name AS event_actual_or_last,
    'order_source' AS dimensions,
    Order_Source AS valores_dimensions,
    SUM(gmv) AS gmv,
    SUM(orders) AS orders
  FROM core_data
  WHERE Order_Source IS NOT NULL
  GROUP BY special_date_name, Order_Source
  
  UNION ALL
  
  SELECT 
    special_date_name AS event_actual_or_last,
    'social_network' AS dimensions,
    Social_Network AS valores_dimensions,
    SUM(gmv) AS gmv,
    SUM(orders) AS orders
  FROM core_data
  WHERE Social_Network IS NOT NULL
  GROUP BY special_date_name, Social_Network
  
  UNION ALL
  
  SELECT 
    special_date_name AS event_actual_or_last,
    'business_unit' AS dimensions,
    business_unit AS valores_dimensions,
    SUM(gmv) AS gmv,
    SUM(orders) AS orders
  FROM core_data
  WHERE business_unit IS NOT NULL
  GROUP BY special_date_name, business_unit
  
  UNION ALL
  
  SELECT 
    special_date_name AS event_actual_or_last,
    'team_last_click' AS dimensions,
    team_last_click AS valores_dimensions,
    SUM(gmv) AS gmv,
    SUM(orders) AS orders
  FROM core_data
  WHERE team_last_click IS NOT NULL
  GROUP BY special_date_name, team_last_click
)

SELECT 
  ad.event_actual_or_last,
  ad.dimensions,
  ad.valores_dimensions,
  ad.gmv,
  ROUND(ad.gmv * 100.0 / et.total_gmv, 2) AS share_gmv,
  ad.orders,
  ROUND(ad.gmv / NULLIF(ad.orders, 0), 2) AS ticket_prom,
  
  CASE 
    WHEN ad.event_actual_or_last = ec.current_event
    THEN ROUND((ad.gmv - COALESCE(last_data.gmv, 0)) * 100.0 / NULLIF(COALESCE(last_data.gmv, 1), 0), 2)
  END AS pct_change_gmv,
  
  CASE 
    WHEN ad.event_actual_or_last = ec.current_event
    THEN ROUND((ad.gmv * 100.0 / et.total_gmv) - COALESCE(last_data.gmv * 100.0 / last_totals.total_gmv, 0), 2)
  END AS pct_change_share_gmv,
  
  CASE 
    WHEN ad.event_actual_or_last = ec.current_event
    THEN ROUND(((ad.gmv / NULLIF(ad.orders, 0)) - COALESCE(last_data.gmv / NULLIF(last_data.orders, 0), 0)) * 100.0 / 
               NULLIF(COALESCE(last_data.gmv / NULLIF(last_data.orders, 0), 1), 0), 2)
  END AS pct_change_ticket_prom

FROM all_dimensions ad
CROSS JOIN events_config ec
LEFT JOIN event_totals et ON ad.event_actual_or_last = et.special_date_name
LEFT JOIN all_dimensions last_data ON ad.dimensions = last_data.dimensions 
  AND ad.valores_dimensions = last_data.valores_dimensions 
  AND last_data.event_actual_or_last = ec.last_event
LEFT JOIN event_totals last_totals ON last_data.event_actual_or_last = last_totals.special_date_name
ORDER BY ad.dimensions, ad.valores_dimensions, ad.event_actual_or_last`;

// 5. PROMOTIONS (CORE - DÍAS COMPLETOS)
const generatePromotions = () => `
WITH ${getRelativeTimeLogic("CORE")},
core_data AS (
  SELECT 
    wr.special_date_name, wr.orders, wr.orders_with_any_promotion, wr.orders_free_shipping,
    wr.orders_promo_price, wr.orders_coupon,
    ec.current_event, ec.last_event
  FROM with_rel wr
  CROSS JOIN current_event_limit cel
  CROSS JOIN events_config ec
  WHERE wr.special_date_name IN (ec.current_event, ec.last_event)
    AND wr.rel_hour <= cel.rel_hour_limit
),
event_totals AS (
  SELECT 
    special_date_name,
    SUM(orders) AS total_orders
  FROM core_data
  GROUP BY special_date_name
),
promotions_data AS (
  SELECT 
    special_date_name AS event_name,
    'orders_with_any_promotion' AS promotions_type,
    SUM(CASE WHEN orders_with_any_promotion > 0 THEN orders ELSE 0 END) AS orders
  FROM core_data
  GROUP BY special_date_name
  
  UNION ALL
  
  SELECT 
    special_date_name AS event_name,
    'orders_free_shipping' AS promotions_type,
    SUM(CASE WHEN orders_free_shipping > 0 THEN orders ELSE 0 END) AS orders
  FROM core_data
  GROUP BY special_date_name
  
  UNION ALL
  
  SELECT 
    special_date_name AS event_name,
    'orders_promo_price' AS promotions_type,
    SUM(CASE WHEN orders_promo_price > 0 THEN orders ELSE 0 END) AS orders
  FROM core_data
  GROUP BY special_date_name
  
  UNION ALL
  
  SELECT 
    special_date_name AS event_name,
    'orders_coupon' AS promotions_type,
    SUM(CASE WHEN orders_coupon > 0 THEN orders ELSE 0 END) AS orders
  FROM core_data
  GROUP BY special_date_name
)

SELECT 
  pd.event_name AS event,
  pd.promotions_type,
  pd.orders,
  ROUND(pd.orders * 100.0 / et.total_orders, 2) AS share_orders,
  
  CASE 
    WHEN pd.event_name = ec.current_event
    THEN ROUND((pd.orders - COALESCE(last_data.orders, 0)) * 100.0 / NULLIF(COALESCE(last_data.orders, 1), 0), 2)
  END AS pct_change_orders,
  
  CASE 
    WHEN pd.event_name = ec.current_event
    THEN ROUND((pd.orders * 100.0 / et.total_orders) - COALESCE(last_data.orders * 100.0 / last_totals.total_orders, 0), 2)
  END AS pct_change_share_orders

FROM promotions_data pd
CROSS JOIN events_config ec
LEFT JOIN event_totals et ON pd.event_name = et.special_date_name
LEFT JOIN promotions_data last_data ON pd.promotions_type = last_data.promotions_type 
  AND last_data.event_name = ec.last_event
LEFT JOIN event_totals last_totals ON last_data.event_name = last_totals.special_date_name
ORDER BY pd.promotions_type, pd.event_name`;

// 6A. TEMPORAL (CORE - DÍAS COMPLETOS)
const generateTemporal = () => `
WITH ${getRelativeTimeLogic("CORE")},
core_data AS (
  SELECT 
    wr.special_date_name, wr.orders, wr.products_quantity, wr.special_date_day, wr.special_date_hour,
    ec.current_event, ec.last_event
  FROM with_rel wr
  CROSS JOIN current_event_limit cel
  CROSS JOIN events_config ec
  WHERE wr.special_date_name IN (ec.current_event, ec.last_event)
    AND wr.rel_hour <= cel.rel_hour_limit
),
pico_ventas AS (
  SELECT 
    CONCAT('Day ', special_date_day, ' Hour ', special_date_hour) AS day_hour,
    SUM(orders) AS total_orders
  FROM core_data
  WHERE special_date_name = (SELECT current_event FROM events_config)
  GROUP BY special_date_day, special_date_hour
  ORDER BY total_orders DESC
  LIMIT 1
),
orders_per_hour AS (
  SELECT 
    special_date_name AS event_name,
    ROUND(AVG(hourly_orders), 2) AS avg_orders_per_hour
  FROM (
    SELECT 
      special_date_name,
      special_date_day,
      special_date_hour,
      SUM(orders) AS hourly_orders
    FROM core_data
    GROUP BY special_date_name, special_date_day, special_date_hour
  ) hourly_data
  GROUP BY special_date_name
),
products_per_hour AS (
  SELECT 
    special_date_name AS event_name,
    ROUND(AVG(hourly_products), 2) AS avg_products_per_hour
  FROM (
    SELECT 
      special_date_name,
      special_date_day,
      special_date_hour,
      SUM(products_quantity) AS hourly_products
    FROM core_data
    GROUP BY special_date_name, special_date_day, special_date_hour
  ) hourly_data
  GROUP BY special_date_name
)

SELECT 
  ec.current_event AS event_actual_last,
  'Pico de Ventas' AS metric_category,
  pv.day_hour AS metric_value,
  pv.total_orders AS value,
  NULL AS pct_change_vs_last_event
FROM pico_ventas pv
CROSS JOIN events_config ec

UNION ALL

SELECT 
  current_oph.event_name AS event_actual_last,
  'Orders per Hour' AS metric_category,
  'Promedio' AS metric_value,
  current_oph.avg_orders_per_hour AS value,
  ROUND((current_oph.avg_orders_per_hour - COALESCE(last_oph.avg_orders_per_hour, 0)) * 100.0 / 
        NULLIF(COALESCE(last_oph.avg_orders_per_hour, 1), 0), 2) AS pct_change_vs_last_event
FROM orders_per_hour current_oph
CROSS JOIN events_config ec
LEFT JOIN orders_per_hour last_oph ON last_oph.event_name = ec.last_event
WHERE current_oph.event_name = ec.current_event

UNION ALL

SELECT 
  last_oph.event_name AS event_actual_last,
  'Orders per Hour' AS metric_category,
  'Promedio' AS metric_value,
  last_oph.avg_orders_per_hour AS value,
  NULL AS pct_change_vs_last_event
FROM orders_per_hour last_oph
CROSS JOIN events_config ec
WHERE last_oph.event_name = ec.last_event

UNION ALL

SELECT 
  current_pph.event_name AS event_actual_last,
  'Products per Hour' AS metric_category,
  'Promedio' AS metric_value,
  current_pph.avg_products_per_hour AS value,
  ROUND((current_pph.avg_products_per_hour - COALESCE(last_pph.avg_products_per_hour, 0)) * 100.0 / 
        NULLIF(COALESCE(last_pph.avg_products_per_hour, 1), 0), 2) AS pct_change_vs_last_event
FROM products_per_hour current_pph
CROSS JOIN events_config ec
LEFT JOIN products_per_hour last_pph ON last_pph.event_name = ec.last_event
WHERE current_pph.event_name = ec.current_event

UNION ALL

SELECT 
  last_pph.event_name AS event_actual_last,
  'Products per Hour' AS metric_category,
  'Promedio' AS metric_value,
  last_pph.avg_products_per_hour AS value,
  NULL AS pct_change_vs_last_event
FROM products_per_hour last_pph
CROSS JOIN events_config ec
WHERE last_pph.event_name = ec.last_event

ORDER BY metric_category, event_actual_last`;

// 6B. LAST UPDATED (CORE - DÍAS COMPLETOS)
const generateLastUpdated = () => `
WITH ${getRelativeTimeLogic("CORE")},
filtered_data AS (
  SELECT wr.completed_at_local
  FROM with_rel wr
  CROSS JOIN current_event_limit cel
  CROSS JOIN events_config ec
  WHERE wr.special_date_name = ec.current_event
    AND wr.rel_hour <= cel.rel_hour_limit
)

SELECT 
  'Last Updated' AS metric_category,
  MAX(completed_at_local) AS last_updated_timestamp,
  DATE(MAX(completed_at_local)) AS last_updated_date,
  HOUR(MAX(completed_at_local)) AS last_updated_hour
FROM filtered_data`;

// 7A. TRAFFIC (SESSIONS - DÍAS COMPLETOS)
const generateTraffic = () => `
WITH ${getRelativeTimeLogic("SESSIONS")},
core_sessions_data AS (
  SELECT 
    wr.special_date_name, wr.sessions, wr.orders, wr.carritos,
    ec.current_event, ec.last_event
  FROM with_rel wr
  CROSS JOIN current_event_limit cel
  CROSS JOIN events_config ec
  WHERE wr.special_date_name IN (ec.current_event, ec.last_event)
    AND wr.rel_hour <= cel.rel_hour_limit
),
traffic_metrics AS (
  SELECT 
    special_date_name AS event_name,
    SUM(sessions) AS total_sessions,
    SUM(orders) AS total_orders,
    SUM(carritos) AS total_carritos,
    ROUND(SUM(orders) * 100.0 / NULLIF(SUM(sessions), 0), 2) AS cvr_orders_sessions,
    ROUND(SUM(orders) * 100.0 / NULLIF(SUM(carritos), 0), 2) AS cvr_orders_carritos
  FROM core_sessions_data
  GROUP BY special_date_name
)

SELECT 
  current_tm.event_name AS event,
  current_tm.total_sessions AS sessions,
  current_tm.total_orders AS orders,
  current_tm.cvr_orders_sessions,
  current_tm.total_carritos AS carritos,
  current_tm.cvr_orders_carritos,
  
  ROUND((current_tm.total_sessions - COALESCE(last_tm.total_sessions, 0)) * 100.0 / 
        NULLIF(COALESCE(last_tm.total_sessions, 1), 0), 2) AS pct_change_sessions,
  
  ROUND((current_tm.cvr_orders_sessions - COALESCE(last_tm.cvr_orders_sessions, 0)), 2) AS pct_change_cvr_sessions,
  
  ROUND((current_tm.total_carritos - COALESCE(last_tm.total_carritos, 0)) * 100.0 / 
        NULLIF(COALESCE(last_tm.total_carritos, 1), 0), 2) AS pct_change_carritos

FROM traffic_metrics current_tm
CROSS JOIN events_config ec
LEFT JOIN traffic_metrics last_tm ON last_tm.event_name = ec.last_event
WHERE current_tm.event_name = ec.current_event

UNION ALL

SELECT 
  last_tm.event_name AS event,
  last_tm.total_sessions AS sessions,
  last_tm.total_orders AS orders,
  last_tm.cvr_orders_sessions,
  last_tm.total_carritos AS carritos,
  last_tm.cvr_orders_carritos,
  
  NULL AS pct_change_sessions,
  NULL AS pct_change_cvr_sessions,
  NULL AS pct_change_carritos

FROM traffic_metrics last_tm
CROSS JOIN events_config ec
WHERE last_tm.event_name = ec.last_event

ORDER BY event`;

// 7B. SESSIONS LAST UPDATED (SESSIONS - DÍAS COMPLETOS)
const generateSessionsLastUpdated = () => `
WITH ${getRelativeTimeLogic("SESSIONS")},
filtered_data AS (
  SELECT wr.date_hour_local
  FROM with_rel wr
  CROSS JOIN current_event_limit cel
  CROSS JOIN events_config ec
  WHERE wr.special_date_name = ec.current_event
    AND wr.rel_hour <= cel.rel_hour_limit
)

SELECT 
  'Sessions Last Updated' AS metric_category,
  MAX(date_hour_local) AS last_updated_timestamp,
  DATE(MAX(date_hour_local)) AS last_updated_date,
  HOUR(MAX(date_hour_local)) AS last_updated_hour
FROM filtered_data`;

// 8A. PRODUCTS (PRODUCTS - DÍAS COMPLETOS)
const generateProducts = () => `
WITH ${getRelativeTimeLogic("PRODUCTS")},
core_products_data AS (
  SELECT 
    wr.special_date_name, wr.product_type, wr.gmv, wr.products_quantity,
    ec.current_event, ec.last_event
  FROM with_rel wr
  CROSS JOIN current_event_limit cel
  CROSS JOIN events_config ec
  WHERE wr.special_date_name IN (ec.current_event, ec.last_event)
    AND wr.product_type IS NOT NULL
    AND wr.rel_hour <= cel.rel_hour_limit
),
top_10_products AS (
  SELECT 
    product_type,
    SUM(gmv) AS total_gmv
  FROM core_products_data
  WHERE special_date_name = (SELECT current_event FROM events_config)
  GROUP BY product_type
  ORDER BY total_gmv DESC
  LIMIT 10
),
products_metrics AS (
  SELECT 
    cpd.special_date_name AS event_name,
    cpd.product_type,
    SUM(cpd.gmv) AS gmv,
    SUM(cpd.products_quantity) AS product_quantity
  FROM core_products_data cpd
  INNER JOIN top_10_products t10 ON cpd.product_type = t10.product_type
  GROUP BY cpd.special_date_name, cpd.product_type
),
event_totals AS (
  SELECT 
    special_date_name,
    SUM(gmv) AS total_gmv,
    SUM(products_quantity) AS total_product_quantity
  FROM core_products_data
  GROUP BY special_date_name
)

SELECT 
  pm.event_name AS event,
  pm.product_type,
  pm.gmv,
  pm.product_quantity,
  ROUND(pm.gmv * 100.0 / et.total_gmv, 2) AS share_gmv,
  ROUND(pm.product_quantity * 100.0 / et.total_product_quantity, 2) AS share_product_quantity,
  
  CASE 
    WHEN pm.event_name = ec.current_event
    THEN ROUND((pm.gmv - COALESCE(last_pm.gmv, 0)) * 100.0 / 
               NULLIF(COALESCE(last_pm.gmv, 1), 0), 2)
  END AS pct_change_gmv,
  
  CASE 
    WHEN pm.event_name = ec.current_event
    THEN ROUND((pm.product_quantity - COALESCE(last_pm.product_quantity, 0)) * 100.0 / 
               NULLIF(COALESCE(last_pm.product_quantity, 1), 0), 2)
  END AS pct_change_prod_quantity,
  
  CASE 
    WHEN pm.event_name = ec.current_event
    THEN ROUND((pm.gmv * 100.0 / et.total_gmv) - COALESCE(last_pm.gmv * 100.0 / last_et.total_gmv, 0), 2)
  END AS pct_change_share_gmv,
  
  CASE 
    WHEN pm.event_name = ec.current_event
    THEN ROUND((pm.product_quantity * 100.0 / et.total_product_quantity) - COALESCE(last_pm.product_quantity * 100.0 / last_et.total_product_quantity, 0), 2)
  END AS pct_change_share_prod_quantity

FROM products_metrics pm
CROSS JOIN events_config ec
LEFT JOIN event_totals et ON pm.event_name = et.special_date_name
LEFT JOIN products_metrics last_pm ON pm.product_type = last_pm.product_type 
  AND last_pm.event_name = ec.last_event
LEFT JOIN event_totals last_et ON last_pm.event_name = last_et.special_date_name
ORDER BY 
  CASE WHEN pm.event_name = ec.current_event THEN 1 ELSE 2 END,
  pm.gmv DESC`;

// 8B. PRODUCTS LAST UPDATED (PRODUCTS - DÍAS COMPLETOS)
const generateProductsLastUpdated = () => `
WITH ${getRelativeTimeLogic("PRODUCTS")},
filtered_data AS (
  SELECT wr.date_hour_local
  FROM with_rel wr
  CROSS JOIN current_event_limit cel
  CROSS JOIN events_config ec
  WHERE wr.special_date_name = ec.current_event
    AND wr.rel_hour <= cel.rel_hour_limit
)

SELECT 
  'Products Last Updated' AS metric_category,
  MAX(date_hour_local) AS last_updated_timestamp,
  DATE(MAX(date_hour_local)) AS last_updated_date,
  HOUR(MAX(date_hour_local)) AS last_updated_hour
FROM filtered_data`;

// =======================
// 🚚 BUILD & RETURN
// =======================

const queries = [
  { name: "01_general_metrics", generator: generateGeneralMetrics },
  { name: "02a_active_stores", generator: generateActiveStores },
  { name: "02b_business_unit", generator: generateBusinessUnit },
  { name: "02c_store_age", generator: generateStoreAge },
  { name: "03_consumers", generator: generateConsumers },
  { name: "04_shares_analysis", generator: generateShares },
  { name: "05_promotions", generator: generatePromotions },
  { name: "06a_temporal", generator: generateTemporal },
  { name: "06b_last_updated", generator: generateLastUpdated },
  { name: "07a_traffic", generator: generateTraffic },
  { name: "07b_sessions_last_updated", generator: generateSessionsLastUpdated },
  { name: "08a_products", generator: generateProducts },
  { name: "08b_products_last_updated", generator: generateProductsLastUpdated }
];

const items = queries.map(({ name, generator }) => ({
  json: {
    needs_confirmation: false,
    query_name: name,
    sql: minify(generator()),
    event_comparison: `${CFG.CURRENT_EVENT} vs ${CFG.LAST_EVENT}`,
    generated_at: new Date().toISOString(),
    temporal_fix: "COMPLETE_DAYS_ONLY_FILTER_DAY_0_FROM_20H_DAYS_1_2_3_COMPLETE_FIXED_NESTED_AGGREGATION"
  }
}));

return items;
