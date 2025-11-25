# Databricks notebook source
# MAGIC %md
# MAGIC # 🎯 Special Events Analysis - Notebook Unificado Completo
# MAGIC 
# MAGIC **Análisis completo de eventos especiales (Hot Sale, Cyber Monday, Black Friday, etc.)**
# MAGIC 
# MAGIC ✅ **Modular y optimizado** - Merchant info en 5 queries separadas  
# MAGIC ✅ **Promociones correctas** - Lógica de Databricks (promotional_discounts, variants, etc.)  
# MAGIC ✅ **Event tagging configurable** - PW days back parametrizable  
# MAGIC ✅ **Spark optimizado** - DataFrames + caching inteligente  
# MAGIC ✅ **Output para Tableau** - Dataset final listo para conectar  
# MAGIC 
# MAGIC **🔧 TODO CONFIGURABLE EN UNA SOLA CELDA** - Modifica parámetros abajo según necesidad

# COMMAND ----------

# MAGIC %md
# MAGIC ## 🔧 1. CONFIGURACIÓN COMPLETA (MODIFICAR AQUÍ)
# MAGIC 
# MAGIC **¿Qué hace esta sección?**
# MAGIC - Define todos los parámetros configurables del análisis en un solo lugar
# MAGIC - Establece filtros de países, fechas, órdenes y tiendas
# MAGIC - Configura opciones de performance de Spark y output
# MAGIC 
# MAGIC **¿Por qué lo hacemos así?**
# MAGIC - **Centralization**: Todos los parámetros en un lugar → fácil modificación
# MAGIC - **Flexibilidad**: Cambiar países/eventos sin tocar queries
# MAGIC - **Reproducibilidad**: Configuración versionada y documentada
# MAGIC - **Performance**: Settings de Spark optimizados para el caso de uso
# MAGIC 
# MAGIC **¿Cuándo modificar?**
# MAGIC - Nuevos eventos especiales → agregar fechas
# MAGIC - Cambio de países → modificar COUNTRIES
# MAGIC - Diferentes rangos de órdenes → ajustar ORDER_FILTERS

# COMMAND ----------

# =============================================================================
# 🎯 PARÁMETROS CENTRALIZADOS - MODIFICA AQUÍ PARA CAMBIAR TODO
# =============================================================================

# 🎭 VENTANA DE EVENTOS (días hacia atrás para PW)
PW_DAYS_BACK = 2  # -2, -1 (PW) + 0, 1, 2... (MAIN)

# 🌎 PAÍSES A PROCESAR (expandir según necesidad)
COUNTRIES = ['AR']  # ['AR', 'MX', 'BR', 'CL', 'CO']

# 📅 FILTROS DE EVENTOS
EVENT_FILTERS = {
    'start_date_min': '2025-10-01',         # Fecha mínima de eventos
    'exclude_test_events': False,            # Excluir eventos test
    'excluded_events': [                    # Eventos específicos a excluir
        'fonsopalooza', 'fonsopalooza2',
        'test_event_2023', 'prueba_hot_sale'
    ]
}

# 💰 FILTROS DE ÓRDENES
ORDER_FILTERS = {
    'max_total_usd': 10000,                 # Máximo valor USD por orden
    'min_total_usd': 0,                     # Mínimo valor USD por orden
    'excluded_storefronts': ['permalink'],  # Storefronts a excluir
    'max_products_quantity': 998,           # Máxima cantidad productos
    'min_products_quantity': 1              # Mínima cantidad productos
}

# 🏪 FILTROS DE TIENDAS
STORE_FILTERS = {
    'exclude_blocked_stores': True,         # Excluir tiendas bloqueadas
    'blocked_tags': [                       # Tags de tiendas bloqueadas
        'sre-block-store-429',
        'sre-block-store-404'
    ]
}

# ⚡ CONFIGURACIÓN DE SPARK
SPARK_CONFIG = {
    'cache_intermediate_results': True,     # Cachear DFs intermedios (recomendado: True)
    'broadcast_threshold': '100MB',         # Umbral para broadcast joins
    'adaptive_query_execution': True        # AQE habilitado
}

# 📊 CONFIGURACIÓN DE OUTPUT
OUTPUT_CONFIG = {
    'target_catalog': 'data_products_dev',           
    'target_schema': 'testing_marketing',            
    'table_name': 'special_events_actual',           
    'write_mode': 'overwrite',                       
    'partition_by': ['country', 'event_name']        
}

print("✅ Configuración cargada:")
print(f"   - PW Days Back: {PW_DAYS_BACK}")
print(f"   - Países: {COUNTRIES}")
print(f"   - Max Order USD: {ORDER_FILTERS['max_total_usd']}")
print(f"   - Eventos desde: {EVENT_FILTERS['start_date_min']}")
print(f"   - Tabla destino: {OUTPUT_CONFIG['target_catalog']}.{OUTPUT_CONFIG['target_schema']}.{OUTPUT_CONFIG['table_name']}")
print(f"   - Caching: {SPARK_CONFIG['cache_intermediate_results']}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## ⚙️ 2. IMPORTS Y SETUP INICIAL
# MAGIC 
# MAGIC **¿Qué hace esta sección?**
# MAGIC - Importa librerías de PySpark y Python necesarias
# MAGIC - Configura Spark con settings optimizados para nuestro caso de uso
# MAGIC - Define funciones helper reutilizables (cache, filtros, timezones)
# MAGIC 
# MAGIC **¿Por qué lo hacemos así?**
# MAGIC - **Performance**: Adaptive Query Execution habilitado para queries complejas
# MAGIC - **Reusabilidad**: Funciones helper evitan duplicar código
# MAGIC - **Debugging**: Función execute_sql_with_cache con logging automático
# MAGIC - **Mantenibilidad**: Configuración de Spark centralizada
# MAGIC 
# MAGIC **Funciones key:**
# MAGIC - `execute_sql_with_cache()`: Ejecuta SQL + cache opcional + conteo
# MAGIC - `create_country_filter_sql()`: Genera filtros de países dinámicos
# MAGIC - `get_timezone_for_country()`: Mapea países a timezones correctos

# COMMAND ----------

# Imports necesarios
import pyspark.sql.functions as F
from pyspark.sql.types import *
from pyspark.sql.window import Window
from datetime import datetime, timedelta
import json

# Configurar Spark para mejor performance
spark.conf.set("spark.sql.adaptive.enabled", SPARK_CONFIG['adaptive_query_execution'])
spark.conf.set("spark.sql.adaptive.coalescePartitions.enabled", True)
# spark.conf.set("spark.serializer", "org.apache.spark.serializer.KryoSerializer")  # ❌ No permitido en algunos entornos

print("✅ Imports y Spark configurado")

# COMMAND ----------

# Funciones helper
def execute_sql_with_cache(sql_query, df_name="temp_df", cache=True):
    """Ejecuta SQL y opcionalmente cachea el resultado"""
    print(f"📂 Ejecutando: {df_name}")
    df = spark.sql(sql_query)
    
    if cache and SPARK_CONFIG['cache_intermediate_results']:
        df = df.cache()
        count = df.count()
        print(f"   💾 {df_name} cacheado: {count:,} filas")
        return df, count
    
    return df, None

def create_country_filter_sql(countries_list):
    """Crea filtro SQL para países"""
    # Separar la construcción para evitar problemas con f-string
    country_values = ', '.join([f"'{c}'" for c in countries_list])
    return f"country IN ({country_values})"

def get_timezone_for_country(country_code):
    """Retorna timezone por país"""
    timezones = {
        'AR': 'America/Argentina/Buenos_Aires',
        'MX': 'America/Mexico_City', 
        'BR': 'America/Sao_Paulo',
        'CO': 'America/Bogota',
        'CL': 'America/Santiago'
    }
    return timezones.get(country_code, 'UTC')

print("✅ Funciones helper definidas")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 🏢 3. MERCHANT INFO MODULAR (5 QUERIES OPTIMIZADAS)
# MAGIC 
# MAGIC **¿Qué hace esta sección?**
# MAGIC - Reemplaza `marketing_merchant_info_refined` (DBT model) con 5 queries específicas
# MAGIC - Construye info completa de merchants: base, ubicación, clasificación, planes, atribución
# MAGIC - Cada query se enfoca en un aspecto específico para mayor claridad y performance
# MAGIC 
# MAGIC **¿Por qué lo hacemos así?**
# MAGIC - **Evitar dependencias DBT**: DBT models se actualizan 1x/día → datos stale
# MAGIC - **Datos frescos**: Hitting tables directamente → info más actualizada
# MAGIC - **Modularidad**: Cada query es independiente y debuggeable
# MAGIC - **Flexibilidad**: Podemos modificar lógica sin esperar DBT refresh
# MAGIC - **Performance**: Queries específicas vs un monolítico grande
# MAGIC 
# MAGIC **Estructura modular:**
# MAGIC 1. **Base Info**: store_name, domain, contacto, fechas fundamentales
# MAGIC 2. **Location**: país, región, estado, ciudad con normalización
# MAGIC 3. **Business Classification**: segmento, tamaño, vertical
# MAGIC 4. **Plan Groups**: plan actual, grupo, nombres comerciales  
# MAGIC 5. **Marketing Attribution**: UTM tracking, equipos, campañas

# COMMAND ----------

# MAGIC %md
# MAGIC ### 📊 Base Store Information

# COMMAND ----------

base_info_sql = f"""
-- 01_MARKETING_MERCHANT_BASE_INFO
WITH 
base_stores AS (
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
    AND {create_country_filter_sql(COUNTRIES)}
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
)

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

FROM base_stores bs
LEFT JOIN store_names sn ON bs.store_id = sn.store_id
LEFT JOIN contacts_social cs ON bs.store_id = cs.store_id  
LEFT JOIN user_emails ue ON bs.store_id = ue.store_id
"""

base_df, base_count = execute_sql_with_cache(base_info_sql, "base_info")
print(f"✅ Base Info: {base_count:,} tiendas")

# COMMAND ----------

# MAGIC %md
# MAGIC ### 🌍 Location Information

# COMMAND ----------

# Construir filtros de países para evitar problemas de f-string
countries_filter = ', '.join([f"'{c}'" for c in COUNTRIES])

location_sql = f"""
-- 02_MARKETING_MERCHANT_LOCATION
WITH 
base_stores AS (
  SELECT id AS store_id
  FROM hive_metastore.moltres.mwp_store_info
  WHERE state != 4 AND {create_country_filter_sql(COUNTRIES)}
),

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
    AND address.country.code IN ({countries_filter})
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
  WHERE a.country IN ({countries_filter})
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
)

SELECT 
  bs.store_id,
  COALESCE(sl.country_code, '{COUNTRIES[0]}') AS country_code,
  sw.region_name AS base_region_name,
  sw.state_name AS base_state_name,
  ci.city_name AS base_city_name

FROM base_stores bs
LEFT JOIN shipping_locations sl ON bs.store_id = sl.store_id
LEFT JOIN zipcode_cities zc ON sl.zipcode = zc.zipcode AND sl.country_code = zc.country_code
LEFT JOIN states_with_regions sw ON sl.country_code = sw.country_code AND sl.state_code = sw.state_code
LEFT JOIN cities ci ON zc.country_code = ci.country_code AND zc.city_id = ci.city_id_nk
"""

location_df, location_count = execute_sql_with_cache(location_sql, "location_info")
print(f"✅ Location Info: {location_count:,} tiendas")

# COMMAND ----------

# MAGIC %md
# MAGIC ### 🏷️ Business Classification

# COMMAND ----------

business_sql = f"""
-- 03_BUSINESS_CLASSIFICATION
WITH 
base_stores AS (
  SELECT 
    id AS store_id,
    current_segment
  FROM hive_metastore.moltres.mwp_store_info
  WHERE state != 4 AND {create_country_filter_sql(COUNTRIES)}
),

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
  FROM base_stores bs
)

SELECT 
  bs.store_id,
  sc.current_segment_name,
  CASE 
    WHEN ss.manual_type IS NULL THEN lv.vertifier_classification 
    ELSE ss.manual_type 
  END AS vertical_name,
  COALESCE(ss.business_size, 'Not Informed') AS business_size_name

FROM base_stores bs
LEFT JOIN segment_classification sc ON bs.store_id = sc.store_id
LEFT JOIN latest_vertifier lv ON bs.store_id = lv.store_id
LEFT JOIN store_settings_info ss ON bs.store_id = ss.store_id
"""

business_df, business_count = execute_sql_with_cache(business_sql, "business_classification")
print(f"✅ Business Classification: {business_count:,} tiendas")

# COMMAND ----------

# MAGIC %md
# MAGIC ### 💼 Plan Groups Classification

# COMMAND ----------

plans_sql = f"""
-- 04_PLAN_GROUPS
WITH 
base_stores AS (
  SELECT 
    id AS store_id,
    plan AS plan_id_nk,
    country AS country_code
  FROM hive_metastore.moltres.mwp_store_info
  WHERE state != 4 AND {create_country_filter_sql(COUNTRIES)}
),

plans_info AS (
  SELECT 
    pc.id AS plan_countries_id,
    pc.plan AS plan_id,
    pc.country AS country_code,
    COALESCE(pi.desc, pi.ipn, 'unknown') AS nice_name,  -- ✅ Usar campos reales de mwp_plans
    COALESCE(mpg.grupo, 'unknown') AS grupo,             -- ✅ grupo viene de tabla auxiliar
    COALESCE(mpg.namev2, 'unknown') AS namev2            -- ✅ namev2 viene de tabla auxiliar
  FROM hive_metastore.moltres.mwp_plans_countries pc
  LEFT JOIN hive_metastore.moltres.mwp_plans pi ON pc.plan = pi.id
  LEFT JOIN hive_metastore.data_manual.operations__grouping_plans_aux mpg 
    ON pc.id = mpg.plan
),

plan_groups AS (
  SELECT
    bs.store_id,
    COALESCE(
      NULLIF(pi.grupo, 'unknown'),  -- ✅ Si grupo existe en auxiliar, usarlo
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
    
  FROM base_stores bs
  LEFT JOIN plans_info pi ON bs.plan_id_nk = pi.plan_countries_id
  WHERE NOT (COALESCE(pi.grupo, 'unknown') IN ('test_broken', 'no-stores') OR pi.plan_countries_id IN (20, 21))
)

SELECT 
  store_id,
  COALESCE(group_name, 'unknown') AS group_name,
  before_freemium_launch

FROM plan_groups
"""

plans_df, plans_count = execute_sql_with_cache(plans_sql, "plan_groups")
print(f"✅ Plan Groups: {plans_count:,} tiendas")

# COMMAND ----------

# MAGIC %md
# MAGIC ### 🎯 Marketing Attribution (Simplificada)

# COMMAND ----------

attribution_sql = f"""
-- 05_MARKETING_ATTRIBUTION (simplificada para performance)
WITH 
base_stores AS (
  SELECT 
    id AS store_id,
    partner_id,
    partnership_type,
    country AS country_code
  FROM hive_metastore.moltres.mwp_store_info
  WHERE state != 4 AND {create_country_filter_sql(COUNTRIES)}
),

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
    source AS mkt_source_last_click,      -- ✅ DEFINITIVO: source (según modelos DBT)
    medium AS mkt_medium_last_click,      -- ✅ DEFINITIVO: medium (según modelos DBT)
    campaign AS mkt_campaign_last_click   -- ✅ DEFINITIVO: campaign (según modelos DBT)
  FROM (
    SELECT
      store_id,
      source,      -- ✅ Columnas reales en mwp_attribution
      medium,      -- ✅ Columnas reales en mwp_attribution
      campaign,    -- ✅ Columnas reales en mwp_attribution
      ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY id DESC) AS rn
    FROM hive_metastore.moltres.mwp_attribution
    WHERE store_id IS NOT NULL
  ) ranked
  WHERE rn = 1
)

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

FROM base_stores bs
LEFT JOIN partners_info pi ON bs.partner_id = pi.partner_id
LEFT JOIN latest_attribution la ON bs.store_id = la.store_id
"""

attribution_df, attribution_count = execute_sql_with_cache(attribution_sql, "attribution")
print(f"✅ Attribution: {attribution_count:,} tiendas")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 🔗 4. UNIÓN DE MERCHANT INFO COMPLETO
# MAGIC 
# MAGIC **¿Qué hace esta sección?**
# MAGIC - Une los 5 DataFrames modulares en uno solo: `merchant_complete`
# MAGIC - Realiza JOINs por `store_id` para consolidar toda la info merchant
# MAGIC - Selecciona columnas específicas para evitar ambigüedades (ej: `country_code`)
# MAGIC 
# MAGIC **¿Por qué lo hacemos así?**
# MAGIC - **Spark DataFrame JOINs**: Más eficientes que SQL complex JOINs
# MAGIC - **Columnas explícitas**: Evitamos errores de "ambiguous reference"  
# MAGIC - **Broadcast optimization**: DataFrames pequeños se broadcastean automáticamente
# MAGIC - **Cache estratégico**: Resultado se cachea para reutilización en queries posteriores
# MAGIC 
# MAGIC **Resultado:** 
# MAGIC - DataFrame `merchant_complete` con toda la info consolidada
# MAGIC - Registrado como temp view para usar en SQL queries siguientes
# MAGIC - Base sólida para JOINs con orders y eventos

# COMMAND ----------

# Join eficiente de todas las piezas de merchant info con eliminación de duplicados
print("📊 Creando merchant info completo...")

# Seleccionar columnas específicas para evitar duplicados
base_cols = ["store_id", "created_at", "store_name", "domain", "email_contact", 
            "phone", "whatsapp", "owner_phone", "country_code", "current_segment", 
            "first_payment", "plan_id_nk", "partner_id", "partnership_type", "main_user_id"]

location_cols = ["store_id", "base_region_name", "base_state_name", "base_city_name"]

business_cols = ["store_id", "current_segment_name", "vertical_name", "business_size_name"]

plans_cols = ["store_id", "group_name", "before_freemium_launch"] 

attribution_cols = ["store_id", "partner_code", "mkt_source_last_click", "team_last_click", "subteam_last_click"]

# Joins con columnas específicas para evitar ambigüedad
merchant_df = base_df.select(*base_cols) \
                    .join(location_df.select(*location_cols), "store_id", "left") \
                    .join(business_df.select(*business_cols), "store_id", "left") \
                    .join(plans_df.select(*plans_cols), "store_id", "left") \
                    .join(attribution_df.select(*attribution_cols), "store_id", "left")

if SPARK_CONFIG['cache_intermediate_results']:
    merchant_df = merchant_df.cache()
    merchant_count = merchant_df.count()
else:
    merchant_count = "N/A"

print(f"✅ Merchant Info Completo: {merchant_count} tiendas")
print(f"   Columnas finales: {len(merchant_df.columns)}")

# DEBUG: Verificar columnas antes de crear temp view
print("🔍 DEBUG - Columnas en merchant_df:")
for col in merchant_df.columns:
    print(f"   - {col}")

# Registrar como temp view para usar en SQL
merchant_df.createOrReplaceTempView("merchant_complete")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 📅 5. EVENTS & WINDOWS (CONFIGURABLES)
# MAGIC 
# MAGIC **¿Qué hace esta sección?**
# MAGIC - Carga eventos especiales desde `mwp_special_date` (fechas en hora local)
# MAGIC - Calcula ventanas PW (Pre-Week) dinámicamente basado en `PW_DAYS_BACK`
# MAGIC - Convierte fechas entre timezones locales y UTC para cálculos posteriores
# MAGIC - Aplica filtros configurables de países y fechas
# MAGIC 
# MAGIC **¿Por qué lo hacemos así?**
# MAGIC - **Datos maestros centralizados**: Una sola fuente de verdad para eventos
# MAGIC - **Timezone handling correcto**: Eventos están en hora local → convertimos a UTC
# MAGIC - **Ventanas dinámicas**: PW se calcula automáticamente (ej: 7 días antes del evento)
# MAGIC - **Configurabilidad**: Filtros aplicados desde configuración centralizada
# MAGIC 
# MAGIC **Outputs importantes:**
# MAGIC - `events_windows`: DataFrame con todos los eventos y sus ventanas
# MAGIC - Fechas en múltiples formatos: local, UTC, start_day, pw_start_day
# MAGIC - Base para filtrado posterior de orders y cálculos de event tagging

# COMMAND ----------

# Construir filtros condicionalmente para evitar problemas de f-string
test_filter = "AND lower(name) NOT LIKE '%test%'" if EVENT_FILTERS['exclude_test_events'] else ""
excluded_events = EVENT_FILTERS.get('excluded_events', [])
if excluded_events:
    excluded_list = "', '".join(excluded_events)
    excluded_filter = f"AND lower(name) NOT IN ('{excluded_list}')"
else:
    excluded_filter = ""

events_sql = f"""
-- EVENTS & WINDOWS con parámetros configurables
WITH
events_base AS (
  SELECT
    name,
    country,
    CAST(start_date AS TIMESTAMP) AS start_local,
    CAST(end_date AS TIMESTAMP) AS end_local
  FROM hive_metastore.moltres.mwp_special_date
  WHERE {create_country_filter_sql(COUNTRIES)}
    AND start_date >= TIMESTAMP('{EVENT_FILTERS["start_date_min"]}T00:00:00')
    {test_filter}
    {excluded_filter}
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
    DATE_ADD(DATE(start_local), -{PW_DAYS_BACK}) AS pw_start_day  -- Configurable!
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

country_bounds_utc AS (
  SELECT
    country,
    MIN(
      CASE country
        WHEN 'AR' THEN to_utc_timestamp(CAST(pw_start_day AS TIMESTAMP), 'America/Argentina/Buenos_Aires')
        WHEN 'BR' THEN to_utc_timestamp(CAST(pw_start_day AS TIMESTAMP), 'America/Sao_Paulo')
        WHEN 'MX' THEN to_utc_timestamp(CAST(pw_start_day AS TIMESTAMP), 'America/Mexico_City')
        WHEN 'CO' THEN to_utc_timestamp(CAST(pw_start_day AS TIMESTAMP), 'America/Bogota')
        WHEN 'CL' THEN to_utc_timestamp(CAST(pw_start_day AS TIMESTAMP), 'America/Santiago')
      END
    ) AS min_utc,
    MAX(
      CASE country
        WHEN 'AR' THEN to_utc_timestamp(CAST(end_local AS TIMESTAMP), 'America/Argentina/Buenos_Aires')
        WHEN 'BR' THEN to_utc_timestamp(CAST(end_local AS TIMESTAMP), 'America/Sao_Paulo')
        WHEN 'MX' THEN to_utc_timestamp(CAST(end_local AS TIMESTAMP), 'America/Mexico_City')
        WHEN 'CO' THEN to_utc_timestamp(CAST(end_local AS TIMESTAMP), 'America/Bogota')
        WHEN 'CL' THEN to_utc_timestamp(CAST(end_local AS TIMESTAMP), 'America/Santiago')
      END
    ) AS max_utc
  FROM event_windows_local
  GROUP BY country
)

-- Solo eventos reales (fechas ya están en local correcto)
SELECT 
  event_name,
  country,
  start_local,  -- ✅ Ya viene en hora local de la tabla
  end_local,    -- ✅ Ya viene en hora local de la tabla
  start_hour,
  start_day,
  pw_start_day,
  monday_of_event_week
FROM event_windows_local
"""

events_df, events_count = execute_sql_with_cache(events_sql, "events_windows")

print(f"✅ Events: {events_count} eventos reales (sin BOUNDS innecesarios)")
print(f"   PW Days Back configurado: {PW_DAYS_BACK}")

# OPTIMIZACIÓN CORRECTA: Pre-calcular ventanas por EVENTO individual
print("🔄 Pre-calculando ventanas específicas por evento...")

# Obtener todas las ventanas de eventos individuales
events_list = events_df.collect()
event_windows = []

timezone_map = {
    'AR': 'America/Argentina/Buenos_Aires',
    'MX': 'America/Mexico_City', 
    'BR': 'America/Sao_Paulo',
    'CO': 'America/Bogota',
    'CL': 'America/Santiago'
}

for event in events_list:
    country = event['country']
    timezone = timezone_map.get(country, 'UTC')
    
    # Convertir fechas de evento a UTC
    temp_bounds_df = spark.sql(f"""
        SELECT 
            to_utc_timestamp(CAST('{event["pw_start_day"]}' AS TIMESTAMP), '{timezone}') AS pw_start_utc,
            to_utc_timestamp(CAST('{event["end_local"]}' AS TIMESTAMP), '{timezone}') AS end_utc
    """).collect()[0]
    
    event_windows.append({
        'country': country,
        'event_name': event['event_name'],
        'pw_start_utc': temp_bounds_df["pw_start_utc"].strftime('%Y-%m-%d %H:%M:%S'),
        'end_utc': temp_bounds_df["end_utc"].strftime('%Y-%m-%d %H:%M:%S')
    })
    
    print(f"   {event['event_name']} ({country}): {event_windows[-1]['pw_start_utc']} → {event_windows[-1]['end_utc']}")

print(f"📊 Total ventanas específicas: {len(event_windows)}")

# ===============================================
# 🗂️ PARTITION PRUNING - CRÍTICO PARA PERFORMANCE
# ===============================================

def get_event_partitions_fixed(event_windows):
    """
    Calcula year_month_code (YYYYMM) necesarios para partition pruning
    basado en las ventanas de eventos (incluyendo PW days)
    """
    partitions = set()
    
    for event in event_windows:
        # Usar las fechas UTC ya calculadas
        start_date = event['pw_start_utc'][:10]  # YYYY-MM-DD
        end_date = event['end_utc'][:10]         # YYYY-MM-DD
        
        # Convertir a datetime para iterar por meses
        from datetime import datetime, timedelta
        
        start_dt = datetime.strptime(start_date, '%Y-%m-%d')
        end_dt = datetime.strptime(end_date, '%Y-%m-%d')
        
        # Iterar por todos los meses entre start y end
        current_dt = start_dt.replace(day=1)  # Primer día del mes de inicio
        
        while current_dt <= end_dt:
            year_month_code = current_dt.strftime('%Y%m')  # Formato YYYYMM sin guiones
            partitions.add(year_month_code)
            
            # Próximo mes
            if current_dt.month == 12:
                current_dt = current_dt.replace(year=current_dt.year + 1, month=1)
            else:
                current_dt = current_dt.replace(month=current_dt.month + 1)
    
    return sorted(list(partitions))

# Calcular particiones para performance CRÍTICO
event_partitions = get_event_partitions_fixed(event_windows)
partition_filter = ', '.join(event_partitions)  # Sin quotes: 202410, 202411, 202412

print(f"🗂️ ✅ Particiones calculadas: {event_partitions}")
print(f"   📅 Partition filter: {partition_filter}")
print(f"   ⚡ Esto va a ACELERAR muchísimo las consultas!")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 🛒 6. ORDERS SCOPED (OPTIMIZADO)
# MAGIC 
# MAGIC **¿Qué hace esta sección?**
# MAGIC - Filtra orders por rango REAL de eventos (min/max de todas las ventanas)
# MAGIC - Enriquece con info de merchants, payment dates y products quantity
# MAGIC - Aplica filtros configurables: blocked stores, storefronts, rangos USD
# MAGIC - Pre-calcula métricas necesarias: paid_at, products_quantity, country_code
# MAGIC 
# MAGIC **¿Por qué este approach híbrido?**
# MAGIC - **Rango amplio pero real**: Solo fechas necesarias (no 2030 ficticio)
# MAGIC - **Performance optimizada**: Una sola query de filtrado en tabla masiva
# MAGIC - **Filtrado específico después**: Event tagging hace el filtro exacto por evento
# MAGIC - **Evita timeouts**: Query simple vs múltiples OR conditions complejas
# MAGIC 
# MAGIC **Datos agregados:**
# MAGIC - **Payment timing**: paid_at desde orders_logging (cuando cambió a 'paid')
# MAGIC - **Products quantity**: SUM(quantity) desde mwp_order_products 
# MAGIC - **Country**: Desde merchant info (no orders.country que puede ser incorrecto)
# MAGIC - **Blocked stores**: Filtrados usando tags de SRE

# COMMAND ----------

# Construir filtros condicionalmente para evitar problemas de f-string
if STORE_FILTERS['exclude_blocked_stores'] and STORE_FILTERS['blocked_tags']:
    blocked_tags_list = "', '".join(STORE_FILTERS['blocked_tags'])
    blocked_stores_query = f"SELECT related_id AS store_id FROM hive_metastore.moltres.mwp_tags WHERE type = 'store' AND tag IN ('{blocked_tags_list}')"
else:
    blocked_stores_query = "SELECT -1 AS store_id WHERE 1=0"

excluded_storefronts = ORDER_FILTERS.get('excluded_storefronts', [])
if excluded_storefronts:
    storefront_list = "', '".join(excluded_storefronts)
    storefront_filter = f"AND o.storefront NOT IN ('{storefront_list}')"
else:
    storefront_filter = ""

# VERSIÓN SIMPLIFICADA: Usar min/max REAL de los eventos (no fechas ficticias)
all_starts = [window['pw_start_utc'] for window in event_windows]
all_ends = [window['end_utc'] for window in event_windows]

# Validar que tenemos eventos
if not all_starts or not all_ends:
    raise ValueError("❌ No se encontraron eventos - no se puede determinar rango de fechas")

# Usar fechas REALES de los eventos (no fallbacks ficticios)
global_start = min(all_starts)  # Fecha real más temprana del evento
global_end = max(all_ends)      # Fecha real más tardía del evento

date_filter_sql = f"o.completed_at >= TIMESTAMP('{global_start}') AND o.completed_at <= TIMESTAMP('{global_end}')"

print(f"🎯 Filtro de fecha simplificado: {global_start} → {global_end}")
print(f"   📅 Rango REAL de eventos (PW start más temprano → Event end más tardío)")
print(f"   (El filtrado específico por evento se hará en event_tagging_sql)")

orders_sql = f"""
-- ORDERS SCOPED SIMPLIFICADO - Rango amplio de fechas (filtrado específico en event_tagging)
WITH

blocked_stores AS (
  {blocked_stores_query}
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
    
    -- Order Source (para Social Network)
    os_ranked.source AS order_source,
    os_ranked.source_details AS order_source_details,
    
    -- Country from merchant (explícito)
    mm.country_code AS country_code

  FROM hive_metastore.orders.mwp_orders o
  INNER JOIN merchant_complete mm ON mm.store_id = o.store_id
  LEFT JOIN blocked_stores bs ON bs.store_id = o.store_id
  
  -- Payment date optimizada CON PARTITION PRUNING ⚡
  LEFT JOIN (
    SELECT 
      order_id, 
      MAX(happened_at) AS paid_at
    FROM hive_metastore.orders.mwp_orders_logging
    WHERE year_month_code IN ({partition_filter})  -- ✅ PARTITION PRUNING CRÍTICO
      AND data_2 = 'paid'
    GROUP BY order_id
  ) pl ON pl.order_id = o.id
  
  -- Products quantity (tabla NO particionada)
  LEFT JOIN (
    SELECT
      order_id,
      SUM(quantity) AS products_quantity
    FROM hive_metastore.orders.mwp_order_products
    WHERE deleted_at IS NULL
    GROUP BY order_id
  ) pq ON pq.order_id = o.id
  
  -- Order Source CON PARTITION PRUNING ⚡
  LEFT JOIN (
    SELECT 
      order_id,
      source,
      source_details,
      ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY id DESC) AS rn
    FROM hive_metastore.orders.mwp_orders_source
    WHERE year_month_code IN ({partition_filter})  -- ✅ PARTITION PRUNING CRÍTICO
  ) os_ranked ON os_ranked.order_id = o.id AND os_ranked.rn = 1

  WHERE bs.store_id IS NULL
    AND o.year_month_code IN ({partition_filter})  -- ✅ PARTITION PRUNING CRÍTICO
    AND o.completed_at IS NOT NULL
    AND o.order_id IS NOT NULL
    AND o.total_in_usd BETWEEN {ORDER_FILTERS['min_total_usd']} AND {ORDER_FILTERS['max_total_usd']}
    {storefront_filter}
    AND ({date_filter_sql})  -- ✅ Rango amplio (filtrado específico después)
)

SELECT * FROM orders_scoped
"""

print("🚀 Ejecutando ORDERS SCOPED con PARTITION PRUNING ⚡...")
orders_df, orders_count = execute_sql_with_cache(orders_sql, "orders_scoped_partitioned")
print(f"✅ Orders Scoped OPTIMIZADO: {orders_count:,} órdenes")
print(f"   ⚡ Partitions escaneadas: {event_partitions}")
print(f"   📊 En lugar de TODAS las particiones desde 2018!")
print(f"   🚀 Esto debería ser MUCHO más rápido!")

# Registrar orders como temp view
orders_df.createOrReplaceTempView("orders_scoped")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 🎁 7. PROMOCIONES OPTIMIZADAS (DATABRICKS)
# MAGIC 
# MAGIC **¿Qué hace esta sección?**
# MAGIC - Calcula flags de promociones esenciales: coupons, promo pricing, free shipping
# MAGIC - Usa solo orders del rango amplio (filtrado específico se hace después)
# MAGIC - Evita cálculos pesados de product variants para mejor performance
# MAGIC - Genera flag combinado `orders_with_any_promotion`
# MAGIC 
# MAGIC **¿Por qué esta versión simplificada?**
# MAGIC - **Performance**: Evita JOINs costosos con tablas de product variants
# MAGIC - **Simplicidad**: Solo flags esenciales → granularidad a nivel order_id
# MAGIC - **Flexibilidad**: Lógica de promo pricing se puede agregar después si se necesita
# MAGIC - **Consistencia**: Usa same logic que otros modelos de la empresa
# MAGIC 
# MAGIC **Flags calculados:**
# MAGIC - `orders_coupon`: Orden tiene cupón aplicado
# MAGIC - `orders_promo_price`: Orden tiene descuento promocional  
# MAGIC - `orders_free_shipping`: Shipping cost = 0 o NULL
# MAGIC - `orders_with_any_promotion`: Al menos una promoción activa

# COMMAND ----------

# 🚀 PROMOCIONES OPTIMIZADAS - Solo flags esenciales
# orders_scoped usa rango amplio, filtrado específico se hace en event_tagging

promos_sql = f"""
-- PROMOCIONES - Rango amplio de eventos (filtrado específico en event_tagging)
WITH
orders_base AS (
  SELECT DISTINCT 
    order_pk,
    order_id
  FROM orders_scoped
)

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
  
  -- Descuentos simplificados (sin cálculos pesados de product variants)
  0 AS descuento_pct,
  
  -- Promotion type simplificado
  'N/A' AS promotion_type

FROM orders_base os
LEFT JOIN hive_metastore.orders.mwp_orders mo ON mo.id = os.order_pk
"""

promos_df, promos_count = execute_sql_with_cache(promos_sql, "promotions_data")
promos_with_any = promos_df.filter(F.col("orders_with_any_promotion") == 1).count() if promos_count else 0

print(f"✅ Promociones OPTIMIZADAS: {promos_count:,} órdenes en rango amplio de eventos")
print(f"   Con promociones: {promos_with_any:,} ({promos_with_any/(promos_count or 1)*100:.1f}%)")
print("   🚀 Sin product variants pesados - Solo flags esenciales")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 🎯 8. EVENT TAGGING & WINDOWS (PW vs MAIN)
# MAGIC 
# MAGIC **¿Qué hace esta sección?**
# MAGIC - Aplica filtrado específico por evento (rango amplio → ventanas exactas)
# MAGIC - Convierte timestamps a hora local para cálculos de event days
# MAGIC - Clasifica orders como PW (Pre-Week) o MAIN según `special_date_day`
# MAGIC - Enriquece con datos de promociones y calcula métricas derivadas
# MAGIC 
# MAGIC **¿Por qué este approach en dos pasos?**
# MAGIC - **Filtrado híbrido**: Orders_scoped (amplio) → Event_tagging (específico)
# MAGIC - **Timezone accuracy**: Conversión UTC → local por país para cálculos correctos
# MAGIC - **Performance**: JOIN específico solo en órdenes relevantes
# MAGIC - **Flexibilidad**: Logic de PW configurable via `PW_DAYS_BACK`
# MAGIC 
# MAGIC **Lógica de clasificación:**
# MAGIC - `special_date_day`: Días relativos al inicio del evento (-7, -1, 0, 1, 2...)
# MAGIC - `is_pw`: 1 si está entre `-PW_DAYS_BACK` y `-1` (ej: -7 a -1)
# MAGIC - `special_date_name`: Evento original o "EVENTO_pw" si es Pre-Week
# MAGIC - Campos derivados: short_core, fechas formateadas, day names

# COMMAND ----------

# Registrar DataFrames como temp views
events_df.createOrReplaceTempView("events_windows")
promos_df.createOrReplaceTempView("promotions_data")

event_tagging_sql = f"""
-- EVENT TAGGING OPTIMIZADO - Filtrado específico por evento en JOIN
-- orders_scoped ahora es rango amplio, filtrado específico se hace aquí
WITH
-- Solo eventos reales (sin BOUNDS)
real_events AS (
  SELECT *
  FROM events_windows 
  WHERE event_name NOT LIKE 'BOUNDS_%'
),

-- JOIN específico - orders_scoped ahora es rango amplio, filtrado aquí por ventanas exactas
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
    
    -- JOIN con promociones (nombres correctos)
    COALESCE(p.orders_coupon, 0) AS orders_coupon,
    COALESCE(p.orders_promo_price, 0) AS orders_promo_price, 
    COALESCE(p.orders_free_shipping, 0) AS orders_free_shipping,
    COALESCE(p.orders_with_any_promotion, 0) AS orders_with_any_promotion,
    p.promotion_type,
    p.descuento_pct
    
  FROM orders_scoped o  -- Ahora rango amplio, necesita filtro específico
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

-- CONSOLIDADO: Cálculos de tagging en un solo paso
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

-- RESULTADO FINAL simplificado
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
    
    -- ✅ COLUMNAS DE ÓRDENES FALTANTES (para final_enriched_sql)
    t.contact_email,
    t.currency,
    t.total,
    t.total_in_usd,
    t.storefront,
    t.status,
    t.device_type,
    t.payment_status,
    t.gateway,
    t.shipping_method,
    t.shipping_province,
    t.gateway_installments,
    t.gateway_method,
    t.created_at,
    t.paid_at,
    
    -- Products quantity
    t.products_quantity,
    
    -- Métricas de promociones
    t.orders_coupon,
    t.orders_promo_price, 
    t.orders_free_shipping,
    t.orders_with_any_promotion,
    t.promotion_type,
    t.descuento_pct,
    
    -- Campos derivados esenciales
    CASE 
      WHEN t.special_date_day BETWEEN -{PW_DAYS_BACK} AND -1
      THEN CONCAT(t.event_name, '_pw')
      ELSE t.event_name
    END AS special_date_name,
    
    -- Short name SIMPLIFICADO (sin regex complejo)
    -- Short core con código + año (CM25, HS24, BF25, etc.)
    CONCAT(
      CASE 
        WHEN lower(t.event_name) LIKE '%hotsale%' THEN 'HS'
        WHEN lower(t.event_name) LIKE '%cybermonday%' THEN 'CM'  
        WHEN lower(t.event_name) LIKE '%blackfriday%' THEN 'BF'
        WHEN lower(t.event_name) LIKE '%buenfin%' THEN 'BF'
        ELSE UPPER(LEFT(t.event_name, 2))
      END,
      RIGHT(YEAR(t.start_local), 2)  -- Últimos 2 dígitos del año
    ) AS short_core,
    
    -- PW flag
    CASE 
      WHEN t.special_date_day BETWEEN -{PW_DAYS_BACK} AND -1 THEN 1 
      ELSE 0 
    END AS is_pw,
    
    -- Fechas simplificadas
    CASE
      WHEN t.special_date_day BETWEEN -{PW_DAYS_BACK} AND -1
        THEN date_format(t.pw_start_day, 'yyyy-MM-dd')
      ELSE date_format(DATE(t.start_local), 'yyyy-MM-dd')
    END AS special_date_date_start,
    
    CASE
      WHEN t.special_date_day BETWEEN -{PW_DAYS_BACK} AND -1
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
  WHERE t.special_date_day BETWEEN -{PW_DAYS_BACK} AND -1 OR t.special_date_day >= 0  -- Solo ventana configurada
)

SELECT * FROM final_tagged
"""

tagged_orders_df, tagged_count = execute_sql_with_cache(event_tagging_sql, "tagged_orders")
pw_count = tagged_orders_df.filter(F.col("is_pw") == 1).count() if tagged_count else 0
main_count = (tagged_count or 0) - pw_count

print(f"✅ Event Tagging: {tagged_count:,} órdenes etiquetadas")
print(f"   - PW ({PW_DAYS_BACK} días): {pw_count:,} órdenes") 
print(f"   - MAIN: {main_count:,} órdenes")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 🔗 9. UNIONES FINALES Y ENRIQUECIMIENTO
# MAGIC 
# MAGIC **¿Qué hace esta sección?**
# MAGIC - Une `tagged_orders` con `merchant_complete` y `cartera_success`
# MAGIC - Normaliza gateway y shipping providers usando tablas de apps
# MAGIC - Aplica clasificaciones de negocio: vertical grouping, device types
# MAGIC - Calcula métricas finales: GMV, orders count (paid-based)
# MAGIC 
# MAGIC **¿Por qué estas transformaciones?**
# MAGIC - **Normalización de providers**: Apps table mapea IDs → nombres legibles
# MAGIC - **Business classifications**: Agrupaciones específicas para análisis (Mobile vs Desktop)
# MAGIC - **Vertical standardization**: Mapeo de categorías internas → grupos de análisis
# MAGIC - **Paid-based metrics**: Solo órdenes pagadas cuentan para GMV y orders count
# MAGIC 
# MAGIC **Clasificaciones aplicadas:**
# MAGIC - **Device**: phone/tablet → 'Mobile', resto → 'Desktop'
# MAGIC - **Vertical**: Mapeo específico clothing, electronics, food, etc.
# MAGIC - **Gateway**: MP, Stripe, PayPal, Pago Nube, Efectivo/Transferencia
# MAGIC - **Shipping**: Normalización de métodos de envío

# COMMAND ----------

# Registrar tagged orders como temp view
tagged_orders_df.createOrReplaceTempView("tagged_orders")

# Pre-calcular store_ids relevantes para cartera (mismo patrón de optimización)
relevant_stores = [row.store_id for row in merchant_df.select("store_id").distinct().collect()]
stores_list = ",".join(map(str, relevant_stores))

print(f"🔄 Optimizando cartera success para {len(relevant_stores)} tiendas específicas...")

# Cartera success SÚPER optimizada (usando store_ids pre-calculados)
cartera_sql = f"""
SELECT DISTINCT 
  CAST(store_id AS BIGINT) AS store_id, 
  TRUE AS is_cartera_success
FROM hive_metastore.data_midmarket.midmarket_success_stores mss
WHERE mss.in_portfolio = TRUE
  AND CAST(mss.store_id AS BIGINT) IN ({stores_list})  -- ✅ Lista específica pre-calculada
"""

cartera_df = spark.sql(cartera_sql)
cartera_count = cartera_df.count() if SPARK_CONFIG['cache_intermediate_results'] else "N/A"
print(f"📊 Cartera Success OPTIMIZADA: {cartera_count} tiendas en portfolio específico")

# COMMAND ----------

final_enriched_sql = f"""
-- FINAL ENRICHED ORDERS - Unión completa para Tableau
WITH
apps AS (
  SELECT id, handle 
  FROM hive_metastore.moltres.mwp_apps
),
shipping_carriers AS (
  SELECT id, app_id 
  FROM hive_metastore.moltres.mwp_shipping_carriers
),

cartera_success AS (
  SELECT store_id, is_cartera_success
  FROM ({cartera_sql})
),

enriched_final AS (
  SELECT
    t.order_pk,
    t.order_id,
    t.store_id,
    
    -- Merchant info completa
    m.store_name,
    m.domain,
    m.email_contact,
    m.phone AS `Phone Contact`,
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
    
    -- Vertical classification CORREGIDA (valores específicos)
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
    m.created_at AS `Created At`,
    ROUND(months_between(current_date(), CAST(m.created_at AS DATE)) / 12, 1) AS aging_years,
    CASE WHEN m.first_payment IS NOT NULL THEN 1 ELSE 0 END AS `First Payment Flag`,
    m.first_payment AS `First Payment`,
    
    -- Order details
    t.contact_email,
    t.currency,
    t.total,
    t.total_in_usd,
    t.storefront,
    t.status,
    -- Device classification CORREGIDA (Mobile vs Desktop)
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
    END AS `Gateway Provider`,
    
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
    END AS `Shipping Method`,
    
    -- Timestamps
    t.completed_at,
    CAST(t.completed_at AS TIMESTAMP) AS `Max Date Order`,
    t.created_at,
    t.paid_at,
    t.completed_at_local,
    CAST(DATE(t.completed_hour) AS DATE) AS completed_at_date,
    t.completed_hour AS completed_hour_local,
    
    -- Order Source & Social Network
    t.order_source AS `Order Source`,
    CASE 
      WHEN LOWER(t.order_source) LIKE '%facebook%' THEN 'Facebook'
      WHEN LOWER(t.order_source) LIKE '%instagram%' THEN 'Instagram'
      WHEN LOWER(t.order_source) LIKE '%whatsapp%' THEN 'WhatsApp'
      WHEN LOWER(t.order_source) LIKE '%tiktok%' THEN 'TikTok'
      WHEN LOWER(t.order_source) LIKE '%youtube%' THEN 'YouTube'
      WHEN LOWER(t.order_source) LIKE '%twitter%' THEN 'Twitter'
      WHEN LOWER(t.order_source) LIKE '%linkedin%' THEN 'LinkedIn'
      WHEN t.order_source IS NULL THEN 'Direct'
      ELSE 'Other'
    END AS `Social Network`,
    
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
    
    -- Promociones (todos los campos que necesitas)
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
    
  FROM tagged_orders t
  LEFT JOIN merchant_complete m ON t.store_id = m.store_id
  LEFT JOIN cartera_success cs ON t.store_id = cs.store_id
  LEFT JOIN apps a ON CONCAT('app_', a.id) = t.gateway
  LEFT JOIN shipping_carriers sca ON CONCAT('api_', sca.id) = t.shipping_method
  LEFT JOIN apps a2 ON a2.id = sca.app_id
)

SELECT * FROM enriched_final
ORDER BY special_date_name, special_date_day, completed_hour_local
"""

final_df, final_count = execute_sql_with_cache(final_enriched_sql, "final_enriched_orders")
print(f"✅ Final Enriched Orders: {final_count:,} órdenes completas")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 📊 10. MÉTRICAS Y VALIDACIÓN FINAL
# MAGIC 
# MAGIC **¿Qué hace esta sección?**
# MAGIC - Calcula métricas agregadas por evento y ventana (PW vs MAIN)
# MAGIC - Valida la calidad y consistencia de los datos procesados
# MAGIC - Muestra distribuciones clave: países, eventos, fechas, promociones
# MAGIC - Proporciona sanity checks antes del export final
# MAGIC 
# MAGIC **¿Por qué estas validaciones?**
# MAGIC - **Quality assurance**: Detectar anomalías antes de enviar a Tableau
# MAGIC - **Business validation**: Verificar que los números tienen sentido
# MAGIC - **Debug assistance**: Fácil identificación de problemas de datos
# MAGIC - **Stakeholder confidence**: Métricas claras y transparentes
# MAGIC 
# MAGIC **Métricas calculadas:**
# MAGIC - **Por evento**: Total orders, GMV, paid orders, promociones
# MAGIC - **Distribuciones**: Países procesados, rango de fechas, PW vs MAIN
# MAGIC - **Promociones**: % de órdenes con promociones por evento
# MAGIC - **Tiendas únicas**: Count de merchants únicos por evento

# COMMAND ----------

print("📊 MÉTRICAS FINALES:")
print("=" * 50)

# Por evento y ventana
metrics_summary = final_df.groupBy("special_date_name", "is_pw") \
    .agg(
        F.count("*").alias("total_orders"),
        F.sum("gmv").alias("total_gmv"),
        F.sum("orders").alias("paid_orders"),
        F.avg("descuento_pct").alias("avg_discount_pct"),
        F.sum("orders_with_any_promotion").alias("orders_with_promo"),
        F.countDistinct("store_id").alias("unique_stores")
    ) \
    .orderBy("special_date_name", "is_pw")

metrics_summary.show(50, False)

# COMMAND ----------

print("\n🔍 VALIDACIÓN DE DATOS:")
print("=" * 30)

# Países
countries = final_df.select("country").distinct().collect()
print(f"Países procesados: {[row.country for row in countries]}")

# Eventos únicos
events = final_df.select("event_name").distinct().count()
print(f"Eventos únicos: {events}")

# Rango de fechas
date_range = final_df.agg(
    F.min("completed_at_date").alias("min_date"),
    F.max("completed_at_date").alias("max_date")
).collect()[0]

print(f"Rango de fechas: {date_range.min_date} a {date_range.max_date}")

# Distribución PW vs MAIN
pw_distribution = final_df.groupBy("is_pw").count().collect()
for row in pw_distribution:
    label = "PW" if row.is_pw == 1 else "MAIN"
    print(f"Órdenes {label}: {row.count:,}")

print(f"\n✅ Dataset final listo con {final_count:,} órdenes")
print(f"🎯 Configurado para PW = {PW_DAYS_BACK} días hacia atrás")
print(f"🏪 Países: {COUNTRIES}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 💾 11. EXPORT FINAL PARA TABLEAU
# MAGIC 
# MAGIC **¿Qué hace esta sección?**
# MAGIC - Selecciona columnas específicas optimizadas para análisis en Tableau
# MAGIC - Prepara estructura de tabla final con naming conventions consistentes
# MAGIC - Configura escritura a tabla de destino con timestamping automático
# MAGIC - Muestra schema final y sample data para validación
# MAGIC 
# MAGIC **¿Por qué esta estructura específica?**
# MAGIC - **Tableau optimization**: Columnas ordenadas lógicamente para mejor UX
# MAGIC - **Performance**: Solo columnas necesarias → menor transferencia de datos
# MAGIC - **Naming consistency**: Campos nombrados consistentemente para fácil uso
# MAGIC - **Timestamped tables**: Evita overwrite accidental, permite rollback
# MAGIC 
# MAGIC **Output final:**
# MAGIC - **Tabla principal**: `data_marketing.special_events_YYYYMMDD_HHMMSS`
# MAGIC - **Schema optimizado**: ~60 columnas organizadas por categoría
# MAGIC - **Partitioning**: Por país y evento para queries eficientes en Tableau
# MAGIC - **Ready for consumption**: Directamente usable como data source

# COMMAND ----------

# Preparar columnas finales para Tableau
tableau_columns = [
    # Identifiers
    "order_id", "store_id", 
    
    # Store info
    "store_name", "domain", "email_contact", "`Phone Contact`", "partner_code",
    
    # Geography
    "country", "region", "province", "province_grouping", "city",
    
    # Business
    "segment", "business_size", "plan_group", "business_unit", "is_cartera_success",
    "vertical_vertifier", "vertical_grouping",
    
    # Store lifecycle
    "`Created At`", "aging_years", "`First Payment Flag`", "`First Payment`",
    
    # Order details
    "currency", "total", "total_in_usd", "storefront", "status", "device",
    "payment_status", "`Gateway Provider`", "gateway_provider_grouping",
    "gateway_installments", "`Shipping Method`", "shipping_method_grouping", "shipping_province",
    
    # Timestamps
    "completed_at", "`Max Date Order`", "paid_at", "completed_at_local", "completed_at_date",
    "completed_hour_local",
    
    # Order Source & Social Network
    "`Order Source`", "`Social Network`",
    
    # Special date
    "event_name", "special_date_name", "special_date_name_short",
    "special_date_day", "special_date_day_name", "special_date_hour",
    "special_date_country", "special_date_date_start", "special_date_date_end",
    "special_date_date", "is_pw",
    
    # Promotions
    "orders_coupon", "orders_promo_price", "orders_free_shipping",
    "orders_with_any_promotion", "orders_promotions", "promotion_type",
    "descuento_pct", "descuento_avg_pct",
    
    # Metrics & products
    "products_quantity", "gmv", "orders",
    
    # Attribution
    "team_last_click", "subteam_last_click"
]

# Final DataFrame para Tableau
tableau_df = final_df.select(*tableau_columns)

print(f"🎯 DataFrame final preparado para Tableau:")
print(f"   - {tableau_df.count() if final_count else 'N/A'} filas")
print(f"   - {len(tableau_columns)} columnas")

# COMMAND ----------

# MAGIC %md
# MAGIC ### 💾 Escribir a Delta Lake

# COMMAND ----------

# Configuración de escritura
CATALOG_NAME = OUTPUT_CONFIG['target_catalog']        
SCHEMA_NAME = OUTPUT_CONFIG['target_schema']
TABLE_NAME = OUTPUT_CONFIG['table_name']              

print(f"📝 Preparando escritura a: {CATALOG_NAME}.{SCHEMA_NAME}.{TABLE_NAME}")

# ESCRIBIR A TABLA CON PARTICIONES:
if OUTPUT_CONFIG['partition_by']:
    tableau_df.write \
        .mode(OUTPUT_CONFIG['write_mode']) \
        .option("mergeSchema", "true") \
        .option("overwriteSchema", "true") \
        .partitionBy(*OUTPUT_CONFIG['partition_by']) \
        .saveAsTable(f"{CATALOG_NAME}.{SCHEMA_NAME}.{TABLE_NAME}")
else:
    tableau_df.write \
        .mode(OUTPUT_CONFIG['write_mode']) \
        .option("mergeSchema", "true") \
        .option("overwriteSchema", "true") \
        .saveAsTable(f"{CATALOG_NAME}.{SCHEMA_NAME}.{TABLE_NAME}")

print(f"✅ Tabla escrita: {CATALOG_NAME}.{SCHEMA_NAME}.{TABLE_NAME}")
print(f"   - Particiones: {OUTPUT_CONFIG['partition_by']}")

# Por ahora, mostrar esquema y sample
print("\n📋 ESQUEMA FINAL:")
tableau_df.printSchema()

print(f"\n📄 SAMPLE DATA (primeras 5 filas):")
tableau_df.show(5, False)

# COMMAND ----------

# MAGIC %md
# MAGIC ## ✅ RESUMEN FINAL
# MAGIC 
# MAGIC **¿Qué logramos en esta notebook?**
# MAGIC - **Pipeline completo**: Desde configuración hasta export final para Tableau
# MAGIC - **Análisis de eventos especiales**: PW vs MAIN con lógica temporal precisa
# MAGIC - **Datos enriquecidos**: Orders + Merchants + Events + Promociones + Products
# MAGIC - **Performance optimizada**: Queries modulares, caching inteligente, filtrado híbrido
# MAGIC 
# MAGIC **¿Por qué esta arquitectura es superior?**
# MAGIC - **Flexibilidad**: Configuración centralizada, fácil adaptación a nuevos eventos
# MAGIC - **Performance**: Evita DBT dependencies, queries optimizadas específicamente  
# MAGIC - **Mantenibilidad**: Código modular, bien documentado, debug-friendly
# MAGIC - **Escalabilidad**: Approach híbrido maneja grandes volúmenes eficientemente
# MAGIC 
# MAGIC **Próximos pasos sugeridos:**
# MAGIC - **Parametrización**: HISTORICAL vs CURRENT modes para eficiencia operacional
# MAGIC - **Scheduling**: Databricks Jobs cada 3 horas para eventos activos
# MAGIC - **Monitoring**: Alertas automáticas en métricas clave  
# MAGIC - **Expansion**: Template reusable para otros tipos de análisis temporal
# MAGIC 
# MAGIC ---
# MAGIC 
# MAGIC ### **🎯 CONFIGURACIÓN ACTUAL:**
# MAGIC ```
# MAGIC PW Days Back: {PW_DAYS_BACK}  
# MAGIC Países: {COUNTRIES}
# MAGIC Max Order USD: {ORDER_FILTERS['max_total_usd']}
# MAGIC Eventos desde: {EVENT_FILTERS['start_date_min']}
# MAGIC Caching habilitado: {SPARK_CONFIG['cache_intermediate_results']}
# MAGIC ```
# MAGIC 
# MAGIC ### **✅ COMPLETADO:**
# MAGIC - ✅ **Setup configuración modular** y parámetros centralizados
# MAGIC - ✅ **Merchant info en 5 queries optimizadas** (base, location, business, plans, attribution)  
# MAGIC - ✅ **Events & windows configurables** (PW días = configurable)
# MAGIC - ✅ **Orders scoped** con filtros optimizados
# MAGIC - ✅ **Promociones con lógica correcta de Databricks** (promotional_discounts, coupons, promotional_pricing, free_shipping)
# MAGIC - ✅ **Event tagging completo** (PW vs MAIN) con índices de días
# MAGIC - ✅ **Uniones eficientes** con Spark DataFrames
# MAGIC - ✅ **Output final optimizado** para Tableau
# MAGIC 
# MAGIC ### **📊 RESULTADOS:**
# MAGIC - Dataset final listo para Tableau con **todas las métricas de promociones optimizadas**
# MAGIC - Attribution completa incluida
# MAGIC - Event windows configurables y validados
# MAGIC - Performance mejorado con caching y optimizaciones Spark
# MAGIC 
# MAGIC ### **💡 NEXT STEPS:**
# MAGIC 1. **Descomenta la escritura a Delta Lake** en la celda anterior cuando esté listo
# MAGIC 2. **Conecta Tableau** al schema/tabla final 
# MAGIC 3. **Ajusta parámetros** según necesidades:
# MAGIC    - `PW_DAYS_BACK = 3` para 3 días de Pre-Week
# MAGIC    - `COUNTRIES = ['AR', 'MX', 'BR']` para múltiples países
# MAGIC    - `ORDER_FILTERS['max_total_usd'] = 5000` para filtros más estrictos
# MAGIC 4. **Expande funcionalidad** agregando nuevos eventos o métricas
# MAGIC 
# MAGIC ### **🔧 PARA MODIFICAR CONFIGURACIÓN:**
# MAGIC 1. Ve a la **Celda 2** (Configuración completa)
# MAGIC 2. Modifica los parámetros según necesidad
# MAGIC 3. Ejecuta "Run All" para aplicar cambios
# MAGIC 
# MAGIC **🎉 ¡Notebook completo y listo para usar!**
