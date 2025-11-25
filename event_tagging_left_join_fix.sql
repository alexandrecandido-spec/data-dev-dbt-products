-- 🎯 EVENT TAGGING: LEFT JOIN con merchant_complete para no perder orders

-- ❌ ANTES (perdía orders):
FROM orders_scoped o
INNER JOIN real_events e ON o.country_code = e.country

-- ✅ DESPUÉS (conserva todas las orders):
FROM orders_scoped o
-- 🎯 LEFT JOIN: Si no hay merchant info, conservar order con NULLs
LEFT JOIN merchant_complete mm ON mm.store_id = o.store_id
INNER JOIN real_events e ON o.country_code = e.country

-- 🎯 En final_enriched_sql también LEFT JOIN:
FROM tagged_orders t
LEFT JOIN merchant_complete m ON t.store_id = m.store_id  -- ✅ Era INNER JOIN
LEFT JOIN cartera_cached cs ON t.store_id = cs.store_id

-- 🎯 Manejar NULLs en columnas derivadas:
SELECT 
  -- ... otras columnas ...
  
  -- ✅ Manejar NULLs con COALESCE:
  COALESCE(m.store_name, 'Unknown Store') AS store_name,
  COALESCE(m.current_segment_name, 'Not Classified') AS segment,
  COALESCE(m.group_name, 'Unknown Plan') AS plan_group,
  CASE WHEN m.group_name = 'enterprise' THEN 'MM' 
       WHEN m.group_name IS NOT NULL THEN 'SMB' 
       ELSE 'Unknown' 
  END AS business_unit,
  COALESCE(m.team_last_click, 'Unknown') AS team_last_click,
  COALESCE(m.subteam_last_click, 'Unknown') AS subteam_last_click
  
FROM tagged_orders t
LEFT JOIN merchant_complete m ON t.store_id = m.store_id


