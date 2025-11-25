-- ==============================================
-- MARKETING MERCHANT INFO REFINED - RECREACIÓN COMPLETA
-- ==============================================
-- Esta query combina todas las 5 queries anteriores para recrear marketing_merchant_info_refined
-- usando únicamente tablas directas de Databricks (sin modelos DBT)

-- IMPORTANTE: Ejecuta primero las 5 queries por separado y guarda como DataFrames
-- Luego haz joins como se muestra abajo

WITH 
-- CTE equivalente a tu marketing_merchant original
marketing_merchant AS (
  SELECT 
    base.store_id,
    base.created_at,
    base.store_name,
    base.domain,
    base.email AS email_contact,
    base.owner_phone AS phone_contact,
    COALESCE(attr.partner_code, CAST(base.partner_id AS STRING)) AS partner_code,
    base.country_code AS country,
    loc.base_region_name AS region,
    loc.base_state_name AS province,
    loc.base_city_name AS city,
    biz.current_segment_name AS segment,
    biz.business_size_name AS business_size,
    plans.group_name AS plan_group,
    biz.vertical_name AS vertical_vertifier,
    attr.mkt_source_last_click AS team_last_click,
    attr.mkt_subteam_last_click AS subteam_last_click,
    base.first_payment
    
  FROM 
    -- Query 1: Base info (ejecutar 01_marketing_merchant_base_info.sql)
    base_info_df base
    
    -- Query 2: Location (ejecutar 02_marketing_merchant_location.sql)  
    LEFT JOIN location_df loc ON base.store_id = loc.store_id
    
    -- Query 3: Business classification (ejecutar 03_marketing_merchant_business_classification.sql)
    LEFT JOIN business_df biz ON base.store_id = biz.store_id
    
    -- Query 4: Plan groups (ejecutar 04_marketing_merchant_plan_groups.sql)
    LEFT JOIN plans_df plans ON base.store_id = plans.store_id
    
    -- Query 5: Attribution (ejecutar 05_marketing_merchant_attribution.sql) 
    LEFT JOIN attribution_df attr ON base.store_id = attr.store_id
    
  WHERE base.country_code IN ('AR')
)

SELECT * FROM marketing_merchant;

-- ==============================================
-- CÓDIGO PARA NOTEBOOK DATABRICKS
-- ==============================================

/*
# En tu notebook de Databricks:

# 1. Ejecutar cada query y guardar como DataFrame
base_df = spark.sql(open('01_marketing_merchant_base_info.sql').read())
location_df = spark.sql(open('02_marketing_merchant_location.sql').read()) 
business_df = spark.sql(open('03_marketing_merchant_business_classification.sql').read())
plans_df = spark.sql(open('04_marketing_merchant_plan_groups.sql').read())
attribution_df = spark.sql(open('05_marketing_merchant_attribution.sql').read())

# 2. Hacer joins para recrear marketing_merchant_info_refined completo
marketing_merchant_df = base_df \
    .join(location_df, "store_id", "left") \
    .join(business_df, "store_id", "left") \
    .join(plans_df, "store_id", "left") \
    .join(attribution_df, "store_id", "left") \
    .select(
        col("store_id"),
        col("created_at"), 
        col("store_name"),
        col("domain"),
        col("email").alias("email_contact"),
        col("owner_phone").alias("phone_contact"),
        coalesce(col("partner_code"), col("partner_id").cast("string")).alias("partner_code"),
        col("country_code").alias("country"),
        col("base_region_name").alias("region"),
        col("base_state_name").alias("province"), 
        col("base_city_name").alias("city"),
        col("current_segment_name").alias("segment"),
        col("business_size_name").alias("business_size"),
        col("group_name").alias("plan_group"),
        col("vertical_name").alias("vertical_vertifier"),
        col("mkt_source_last_click").alias("team_last_click"),
        col("mkt_subteam_last_click").alias("subteam_last_click"),
        col("first_payment")
    )

# 3. Usar en tu lógica original
marketing_merchant_df.createOrReplaceTempView("marketing_merchant")

# Ahora puedes usar: SELECT * FROM marketing_merchant WHERE country = 'AR'
*/

-- ==============================================
-- CAMPOS ADICIONALES DISPONIBLES
-- ==============================================

/*
Si necesitas campos adicionales que están disponibles en las queries pero no en tu CTE original:

DE BASE_INFO (Query 1):
- phone, whatsapp, doc_type, doc_number
- instagram, instagram_followers, following, posts, posts_likes
- facebook, twitter, tiktok, pinterest
- main_user_id

DE LOCATION (Query 2):  
- country_id, region_id, state_id, city_id (para joins adicionales)

DE BUSINESS (Query 3):
- is_seller, segment_id, segment_order, vertical_id, business_size_id

DE PLANS (Query 4):
- group_desc, group_order_id, before_freemium_launch

DE ATTRIBUTION (Query 5):
- mkt_source_first_click, mkt_subteam_first_click
- mkt_campaign_last_click, mkt_campaign_first_click
- mkt_landing_page_domain_last_click, mkt_landing_page_path_last_click
- mkt_source_partner_click, mkt_subteam_partner_click
- was_new_seller, first_seller_at, churned_at, blocked_fraud_tag
- ql_profile
- partner_name, partner_country_code
*/

-- ==============================================
-- VALIDACIÓN Y TESTING
-- ==============================================

/*
Para validar que tu recreación es correcta:

1. Compara counts:
SELECT COUNT(*) FROM hive_metastore.data_marketing.marketing_merchant_info_refined WHERE country = 'AR'
vs 
SELECT COUNT(*) FROM marketing_merchant

2. Compara algunos registros específicos:
SELECT store_id, store_name, partner_code, segment, team_last_click 
FROM hive_metastore.data_marketing.marketing_merchant_info_refined 
WHERE country = 'AR' AND store_id IN (12345, 67890)

vs

SELECT store_id, store_name, partner_code, segment, team_last_click
FROM marketing_merchant 
WHERE store_id IN (12345, 67890)

3. Valida distribuciones:
SELECT team_last_click, COUNT(*) 
FROM marketing_merchant 
GROUP BY team_last_click 
ORDER BY COUNT(*) DESC
*/


