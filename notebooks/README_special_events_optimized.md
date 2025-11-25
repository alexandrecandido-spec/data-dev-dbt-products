# 🎯 Special Events Analysis - Notebook Unificado Completo

## 📋 Descripción General

**UN SOLO NOTEBOOK** que procesa eventos especiales (Hot Sale, Cyber Monday, Black Friday, etc.) de manera **completamente modular y optimizada** usando **Spark DataFrames** para máxima velocidad y flexibilidad.

**📁 Archivo único:** `special_events_analysis_unified.py`

## 🚀 Características Principales

### ✅ **Modularidad Total**
- **5 queries separadas** para merchant info (reemplaza `marketing_merchant_info_refined`)
- **Configuración centralizada** de parámetros (PW days, países, filtros)
- **Uniones eficientes** con Spark DataFrames (no SQL monolítico)
- **Optimización de memoria** con caching inteligente

### ✅ **Lógicas Optimizadas**
- **Promociones**: Usando tablas correctas de Databricks (`mwp_promotional_discounts`, `mwp_product_variants`, etc.)
- **Free Shipping**: Lógica precisa de `shipping_cost = 0`
- **Event Tagging**: PW vs MAIN configurable con índices de días exactos
- **Attribution**: Simplificada pero completa para performance

### ✅ **Configurabilidad Total**
- **PW Days Back**: Configurable (por defecto 2 días)
- **Países**: Array expandible `['AR', 'MX', 'BR']`
- **Filtros de eventos**: Excluir tests, fechas mínimas, etc.
- **Filtros de órdenes**: USD máximo, storefronts, etc.

## 🛠 Configuración Inicial

### 📋 Parámetros Clave (Modificables en el notebook)

```python
# VENTANA DE EVENTOS
PW_DAYS_BACK = 2  # Solo -2 y -1, luego MAIN (>= 0)

# PAÍSES A PROCESAR  
COUNTRIES = ['AR']  # Expandir a ['AR', 'MX', 'BR'] según necesidad

# FILTROS DE EVENTOS
EVENT_FILTERS = {
    'start_date_min': '2021-01-01',
    'exclude_test_events': True,
    'excluded_events': ['fonsopalooza', 'fonsopalooza2']
}

# FILTROS DE ÓRDENES
ORDER_FILTERS = {
    'max_total_usd': 10000,
    'min_total_usd': 0,
    'excluded_storefronts': ['permalink']
}
```

## 📊 Estructura del Notebook Único

### **1. Configuración Centralizada (Celdas 1-2)**
- **TODOS LOS PARÁMETROS** configurables en una sola celda
- Imports y setup de Spark
- Funciones helper

### **2. Merchant Info Modular (Celdas 3-8)**  
- **Base Info**: Store básica + contactos + social media
- **Location**: Región/provincia/ciudad con zipcode mapping
- **Business Classification**: Segments + verticals + business size  
- **Plan Groups**: Grupos de planes con lógica manual + fallback
- **Attribution**: Teams/subteams con partner info
- **Join Completo**: Unión eficiente de todas las piezas

### **3. Events & Orders (Celdas 9-11)**
- **Events**: Con windows configurables y bounds UTC
- **Orders Scoped**: Filtrados por ventanas de eventos
- **Promociones**: Lógica completa de Databricks

### **4. Event Tagging (Celda 12)**
- **PW vs MAIN**: Con índices de días exactos
- **Labels**: Short names (HS24, CM24, etc.) + fechas

### **5. Output Final (Celdas 13-16)**
- **Join completo** con merchant info
- **Enriquecimiento** final (gateways, shipping, etc.)
- **Métricas de validación**
- **Export para Tableau**

## 🎯 Campos Finales (Para Tableau)

### **📍 Identificadores**
- `order_id`, `store_id`

### **🏢 Store Info**  
- `store_name`, `domain`, `email_contact`, `phone`, `partner_code`

### **🌍 Geografía**
- `country`, `region`, `province`, `province_grouping`, `city`

### **💼 Business**
- `segment`, `business_size`, `plan_group`, `is_cartera_success`
- `vertical_vertifier`, `vertical_grouping`

### **📅 Special Date**
- `event_name`, `special_date_name`, `special_date_name_short`
- `special_date_day`, `special_date_day_name`, `special_date_hour`
- `is_pw` (1 = Pre-Week, 0 = Main Event)

### **🎁 Promociones (OPTIMIZADAS)**
- `orders_coupon` (coupon_id)
- `orders_promo_price` (promotional_price vs price)  
- `orders_free_shipping` (shipping_cost = 0)
- `orders_with_any_promotion` (combinado)
- `promotion_type` (desde JSON contents)
- `descuento_pct` (% descuento weighted)

### **📊 Métricas**
- `gmv`, `orders` (basados en `paid_at` exacto)
- `products_quantity`

### **🎯 Attribution**
- `team_last_click`, `subteam_last_click`

## 🚀 Cómo Usar (Un Solo Notebook)

### **1. Abrir Notebook Único**
```
📁 notebooks/special_events_analysis_unified.py
```

### **2. Configurar Parámetros (Celda 2)**
```python
# MODIFICA AQUÍ - TODO EN UNA SOLA CELDA:
PW_DAYS_BACK = 3                    # Para 3 días de Pre-Week
COUNTRIES = ['AR', 'MX']            # Para múltiples países  
ORDER_FILTERS['max_total_usd'] = 5000  # Para órdenes menores
EVENT_FILTERS['start_date_min'] = '2023-01-01'  # Solo eventos recientes
```

### **3. Ejecutar Completo**
- **"Run All"** para ejecutar todo de una vez
- O celda por celda para revisar cada paso
- Revisa métricas de validación en cada etapa

### **4. Escribir a Tabla (Celda 16)**
```python
# DESCOMENTA estas líneas para escribir:
# tableau_df.write \
#     .mode("overwrite") \
#     .option("mergeSchema", "true") \
#     .saveAsTable(f"data_marketing.special_events_final")
```

### **5. Conectar Tableau**
- Conecta a la tabla Delta creada
- Usa campos de `special_date_*` para análisis
- Filtra por `is_pw` para PW vs MAIN

## ⚡ Optimizaciones Implementadas

### **🔧 Performance**
- **Spark caching** en DataFrames intermedios
- **Broadcast joins** automático para tablas pequeñas
- **Predicado pushdown** en filtros de eventos/órdenes
- **Columnar storage** con Delta Lake

### **💾 Memoria**  
- **Lazy evaluation** hasta el final
- **Garbage collection** automático
- **Particionamiento** por país/evento

### **🔍 Precisión**
- **Timestamps locales** exactos por país
- **Event boundaries** UTC precisos
- **Paid_at timestamp** exacto (no approximation)
- **Latest product variants** para promotional pricing

## 🔄 Expansión a Otros Países

Para agregar Brasil y México:

```python
# 1. Cambiar configuración
COUNTRIES = ['AR', 'MX', 'BR']

# 2. El notebook automáticamente:
# - Agrega zipcode mapping para MX/BR
# - Incluye timezones correctos  
# - Expande region mapping
# - Ajusta event boundaries
```

## 🐛 Troubleshooting

### **❌ Error: Schema mismatch**
- Revisa que todas las tablas existan en Databricks
- Verifica permisos de lectura en `hive_metastore.*`

### **❌ Error: Memory issues**
- Reduce `COUNTRIES` a uno solo
- Ajusta `EVENT_FILTERS['start_date_min']` más reciente
- Desactiva caching con `SPARK_CONFIG['cache_intermediate_results'] = False`

### **❌ Error: Empty results**
- Verifica que existan eventos en `mwp_special_date` para países seleccionados
- Revisa filtros de fechas en `EVENT_FILTERS`
- Valida que las tiendas estén en `marketing_merchant_info_refined`

## 📈 Métricas Esperadas

Para **Argentina Hot Sale 2024**:
- ~50K-200K órdenes (dependiendo de ventana)
- ~15-30% con promociones
- ~60-70% órdenes PW vs 30-40% MAIN
- ~5K-15K tiendas únicas

## 📞 Soporte

Para dudas o mejoras:
1. Revisa este README
2. Ejecuta las celdas de validación en el notebook
3. Verifica logs de Spark en Databricks console
