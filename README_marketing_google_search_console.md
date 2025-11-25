# Google Search Console - Competitive Intelligence Model

## Resumen

Este modelo proporciona **inteligencia competitiva automatizada** desde Google Search Console, transformando datos brutos en insights accionables para Marketing. Incluye detección automática de **65+ marcas competidoras** por país y análisis de intención de búsqueda.

### Capacidades Principales

- **Brand Detection:** D2C platforms y marketplaces por país con sistema de prioridades
- **Intent Analysis:** Clasificación automática de 8 categorías de intención no-branded  
- **Brand Monitoring:** Seguimiento específico de Tiendanube/Nuvemshop y features futuras
- **Competitive Intelligence:** Share of voice y análisis de tendencias competitivas

## Arquitectura

### Modelos

```
📁 intermediate/marketing/
└── _int_marketing_google_search_console_clean.sql

📁 data_product/marketing/
├── marketing_google_search_console_enriched.sql
└── marketing_search_console__schema.yml

📁 macros/
├── get_d2c_brand_detection.sql
├── get_marketplace_brand_detection.sql  
├── get_nonbranded_terms_detection.sql
├── get_country_mapping.sql
└── get_date_dimensions.sql
```

### Capa Intermediate (`_int_marketing_google_search_console_clean`)

**Responsabilidades:**
- Limpieza básica de datos desde Databricks
- Filtrado por fechas, tipo de búsqueda y países
- Mapeo de países basado en site  
- Rectificación de device (NULL → 'DESKTOP')
- Filtros de calidad de datos

**Fuente:** `hive_metastore.third_party.marketing_google_search_console_keyword_searches`

### Capa Silver (`marketing_google_search_console_enriched`)

**Responsabilidades:**
- **Brand Detection:** D2C y Marketplace brands con sistema de prioridades
- **Intent Classification:** Análisis automático de términos no-branded
- **Brand Monitoring:** Flags específicos para Tiendanube y Next Evolution
- **Enrichment:** Dimensiones temporales y métricas derivadas (CTR)

## Nuevos Campos Implementados

### 1. Brand Detection Fields

#### **d2c_brand_names & marketplace_brand_names**
- **Lógica:** Sistema de prioridades automatizado
- **Macros:** `get_d2c_brand_detection()` y `get_marketplace_brand_detection()`
- **Output:** Nombre de marca detectada o NULL
- **Prioridad:** Tiendanube/Nuvemshop → Exact matches → Broad matches

#### **d2c_match_type & marketplace_match_type**  
- **Valores:** 'exact' (query = 'shopify') o 'broad' (query CONTAINS 'shopify')
- **Uso:** Precisión del match para análisis de calidad

### 2. Brand Monitoring Fields

#### **is_nuvemshop_tiendanube**
- **Tipo:** Boolean (true/false)
- **Lógica:** Detecta todas las variantes de nuestras marcas
- **Incluye:** tiendanube, tienda nube, nuvemshop, nuvem shop + variantes por país

#### **is_next_evolucion**
- **Tipo:** Boolean (true/false) 
- **Lógica:** `is_nuvemshop_tiendanube = true` AND contiene 'next'/'evolution'/'evolucion'
- **Uso:** Early detection de features en roadmap

### 3. Non-Branded Intent Fields

#### **non_brand_term**
- **Output:** Término específico detectado ('crear', 'tienda', 'venta', etc.)
- **Lógica:** Primer match según orden de prioridad
- **Macro:** `get_nonbranded_terms_detection()`

#### **non_brand_category** 
- **Categorías:** 'Intention Verbs', 'D2C', 'Vendas', 'Dropshipping', 'Envios', 'Ecommerce', 'Producto', 'Redes Sociales'
- **Prioridad:** Intention Verbs → D2C → Vendas → resto
- **Uso:** Segmentación de oportunidades de mercado

#### **non_brand_match_type**
- **Valores:** 'exact' o 'broad'
- **Lógica:** Similar a brand match types

### 4. Primary Classification

#### **branded_non_branded**
- **Lógica:** 'branded' si hay marca detectada, 'nonbranded' si no hay
- **Reemplaza:** Los campos search_query_type, category, etc.
- **Uso:** Clasificación principal para análisis

## Campos de Salida Final

El modelo `marketing_google_search_console_enriched` incluye:

### **Dimensiones Temporales**
- `date_day`, `date_month`, `date_quarter`, `date_week`, `date_year`

### **Dimensiones Geográficas**  
- `country_detail` (Argentina, Mexico, etc.)
- `country` (AR, MX, BR, etc.)

### **Core Search**
- `search_query` (query original)

### **Brand Intelligence**
- `d2c_brand_names`, `marketplace_brand_names`
- `d2c_match_type`, `marketplace_match_type`
- `is_nuvemshop_tiendanube`, `is_next_evolucion`

### **Non-Branded Intelligence**
- `non_brand_term`, `non_brand_category`, `non_brand_match_type`

### **Classification**
- `branded_non_branded` (clasificación principal)

### **Technical & Metrics**
- `device` (NULL → 'DESKTOP'), `site`
- `impressions`, `clicks`, `average_position`, `click_through_rate`

## Ejemplos de Uso

### **Competitive Analysis**
```sql
-- Top competidores D2C por país
SELECT country, d2c_brand_names, SUM(impressions) as total_impressions
FROM marketing_google_search_console_enriched 
WHERE branded_non_branded = 'branded' AND d2c_brand_names IS NOT NULL
GROUP BY country, d2c_brand_names 
ORDER BY total_impressions DESC
```

### **Brand Monitoring**
```sql
-- Monitoreo de Tiendanube y Next Evolution
SELECT date_month,
       is_nuvemshop_tiendanube,
       is_next_evolucion,
       SUM(impressions) as impressions
FROM marketing_google_search_console_enriched 
WHERE is_nuvemshop_tiendanube = true
GROUP BY date_month, is_nuvemshop_tiendanube, is_next_evolucion
ORDER BY date_month DESC
```

### **Market Opportunity**
```sql
-- Oportunidades non-branded por intención
SELECT non_brand_category, 
       COUNT(DISTINCT search_query) as unique_queries,
       SUM(impressions) as total_volume
FROM marketing_google_search_console_enriched 
WHERE branded_non_branded = 'nonbranded'
GROUP BY non_brand_category 
ORDER BY total_volume DESC
```

## Ventajas del Nuevo Modelo

### ✅ **Inteligencia Automatizada**
- **65+ marcas** monitoreadas automáticamente
- **Sistema de prioridades** evita duplicación
- **Detección automática** de intención de búsqueda

### ✅ **Escalabilidad**
- Fácil adición de nuevos competidores en macros
- Actualizaciones centralizadas por país
- Arquitectura modular para extensiones futuras

## Ejecución

### **Ejecutar Modelos**
```bash
# Pipeline completo
dbt run --select +marketing_google_search_console_enriched

# Solo intermediate
dbt run --select _int_marketing_google_search_console_clean

# Solo final
dbt run --select marketing_google_search_console_enriched
```

### **Tests de Calidad**
```bash
# Todos los tests
dbt test --select marketing_google_search_console_enriched

# Tests específicos
dbt test --select marketing_google_search_console_enriched,test_type:not_null
```

### **Documentación**
```bash
# Generar y servir documentación
dbt docs generate
dbt docs serve
```

## Configuración

### **Fuente de Datos**
- **Tabla:** `hive_metastore.third_party.marketing_google_search_console_keyword_searches`  
- **Configuración:** `nubeproduct/models/intermediate/_intermediate__sources.yml`
- **Filtros:** Países LATAM, search_type = 'WEB', fecha >= 2024-01-01

### **Materialización**
- **Intermediate:** Table (filtros tempranos)
- **Silver:** Table (consultas rápidas)
- **Tests:** Validación automática de calidad

## Status

✅ **Modelo completamente implementado**
- Todas las macros creadas y testeadas
- Documentación completa con schema
- Tests de calidad configurados
- Listo para ejecución en producción

---

*Modelo desarrollado para proporcionar inteligencia competitiva automatizada desde Google Search Console con detección de 65+ marcas y análisis de intención de búsqueda por país.*
