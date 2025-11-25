orders_sql = f"""
-- ORDERS SCOPED - Con manejo de NULLs para merchant_complete faltante
WITH
-- ... CTEs anteriores igual ...

orders_base AS (
  SELECT 
    o.id AS order_pk,
    o.order_id, 
    o.store_id,
    -- ... columnas base de orders ...
    
    -- ✅ SIEMPRE disponible desde store_info
    si.country AS country_code,
    
    -- ✅ MANEJAR NULLs con defaults para merchant info
    COALESCE(mm.store_name, CONCAT('Store_', o.store_id)) AS store_name,
    COALESCE(mm.current_segment_name, 'Not Classified') AS current_segment_name,
    COALESCE(mm.group_name, 'unknown') AS group_name,
    COALESCE(mm.team_last_click, 'Direct') AS team_last_click,
    COALESCE(mm.subteam_last_click, 'Direct') AS subteam_last_click,
    COALESCE(mm.vertical_name, 'Other') AS vertical_name,
    COALESCE(mm.business_size_name, 'Unknown') AS business_size_name,
    COALESCE(mm.partner_code, 'direct') AS partner_code,
    COALESCE(mm.base_region_name, 'Unknown') AS base_region_name,
    COALESCE(mm.base_state_name, 'Unknown') AS base_state_name,
    
    -- ✅ Business unit con manejo de NULL
    CASE 
      WHEN mm.group_name = 'enterprise' THEN 'MM'
      WHEN mm.group_name IS NOT NULL THEN 'SMB' 
      ELSE 'Unknown'  -- ✅ Para NULLs
    END AS business_unit,
    
    -- ... resto columnas ...

  FROM orders_dedup o
  -- 🎯 BASE: Universo completo
  INNER JOIN hive_metastore.moltres.mwp_store_info si ON si.id = o.store_id
  -- 🎯 ENRIQUECIMIENTO: Merchant info opcional
  LEFT JOIN merchant_complete mm ON mm.store_id = o.store_id
  LEFT JOIN blocked_stores bs ON bs.store_id = o.store_id
  
  WHERE bs.store_id IS NULL
    AND si.country IN ({', '.join([f"'{c}'" for c in COUNTRIES])})
    AND si.state <> 4
    -- ... resto filtros exactos repo oficial ...
)
"""


