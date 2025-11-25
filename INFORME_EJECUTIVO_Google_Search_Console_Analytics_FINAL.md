# Google Search Console - Modelo de Inteligencia Competitiva y Brand Monitoring

**Informe Ejecutivo - Noviembre 2024**  
**Equipo de Data Engineering & Marketing Analytics**

---

## Resumen Ejecutivo

Hemos desarrollado un **modelo avanzado de análisis de Google Search Console** que transforma los datos brutos de búsquedas orgánicas en **inteligencia competitiva accionable** para el equipo de Marketing. Este modelo proporciona visibilidad completa del landscape competitivo y el comportamiento de búsqueda de usuarios potenciales en todos nuestros mercados.

---

## 🎯 Objetivos del Modelo

### **Inteligencia Competitiva**
- Monitoreo automático de **65+ marcas competidoras** (D2C y Marketplaces) por país
- Identificación de tendencias de búsqueda por competidor
- Análisis de share of voice vs competencia en búsquedas orgánicas

### **Brand Monitoring**
- Seguimiento específico de variantes Tiendanube/Nuvemshop por mercado
- Detección de menciones de próximas features ("Next", "Evolution") 
- Análisis de branded vs non-branded search performance

### **Market Intelligence**
- Clasificación automática de intención de búsqueda no-branded
- Identificación de oportunidades de mercado por categoría
- Análisis de demanda por país y temporalidad

---

## 🏗️ Arquitectura y Lógica del Modelo

### **Estructura de Datos en 2 Capas**

#### **Capa Intermediate (Limpieza)**
- **Fuente:** `hive_metastore.third_party.marketing_google_search_console_keyword_searches`
- **Funciones:** Filtrado, limpieza básica, mapeo de países
- **Optimizaciones:** Filtros tempranos para mejor performance

#### **Capa Silver (Enriquecimiento)**
- **Funciones:** Detección de marcas, clasificación de intención, métricas derivadas
- **Output:** Modelo final listo para análisis

### **Lógica de Detección de Marcas**

#### **Sistema de Prioridades Automatizado**
```
PRIORIDAD 1: Nuestras marcas (tiendanube, nuvemshop)
PRIORIDAD 2: Variantes por país (tiendanube mexico, tiendanube colombia)
PRIORIDAD 3: Competidores D2C - Matches exactos
PRIORIDAD 4: Competidores D2C - Matches amplios
PRIORIDAD 5: Marketplaces - Matches exactos
PRIORIDAD 6: Marketplaces - Matches amplios
```

#### **Metodología de Match**
- **Match Exacto:** `search_query = 'shopify'` → `d2c_brand_names = 'shopify'`, `match_type = 'exact'`
- **Match Amplio:** `search_query CONTAINS 'shopify'` → `d2c_brand_names = 'shopify'`, `match_type = 'broad'`

### **Algoritmo de Clasificación de Campos**

#### **d2c_brand_names & marketplace_brand_names**
```sql
Lógica: CASE WHEN con sistema de prioridades
- Si contiene 'tiendanube' → 'tiendanube' (máxima prioridad)
- Si país = 'AR' AND query = 'shopify' → 'shopify' (exact)
- Si país = 'AR' AND query CONTAINS 'shopify' → 'shopify' (broad)
- Primero que coincida según orden de prioridad
```

#### **is_nuvemshop_tiendanube**
```sql
Lógica: CASE WHEN (
  CONTAINS('tiendanube') OR CONTAINS('tienda nube') OR
  CONTAINS('nuvemshop') OR CONTAINS('nuvem shop') OR
  CONTAINS('tiendanube mexico') OR CONTAINS('tiendanube méxico') OR
  ... [todas las variantes por país]
) THEN true ELSE false
```

#### **is_next_evolucion**
```sql
Lógica: is_nuvemshop_tiendanube = true AND (
  CONTAINS('next') OR CONTAINS('evolution') OR 
  CONTAINS('evolucion') OR CONTAINS('evolución')
)
```

#### **branded_non_branded**
```sql
Lógica: CASE 
  WHEN d2c_brand_names IS NOT NULL 
    OR marketplace_brand_names IS NOT NULL 
  THEN 'branded'
  ELSE 'nonbranded'
```

### **Sistema de Detección Non-Branded**

#### **Clasificación por Prioridad**
```
1. Intention Verbs (crear, hacer, trabajar)
   - Exact: query = 'crear' → 'crear', 'Intention Verbs', 'exact'
   - Broad: query CONTAINS 'crear' → 'crear', 'Intention Verbs', 'broad'

2. D2C Terms (tienda, loja, sitio)
3. Vendas (venta, venda, vender)  
4. Dropshipping, Envios, Ecommerce, etc.
```

#### **Lógica de Exclusión**
- Solo se ejecuta si **NO** hay marcas detectadas
- Evita conflictos entre branded y non-branded
- Garantiza clasificación mutuamente excluyente

---

## 📊 Estructura de Datos Final

### **Dimensiones Temporales**
- `date_day`: YYYY-MM-DD
- `date_month`: YYYY-MM  
- `date_quarter`: YYYY-QN
- `date_week`: YYYY-MM-DD (lunes como inicio)
- `date_year`: YYYY

### **Campos de Inteligencia Competitiva**

#### **Brand Detection**
- `d2c_brand_names`: Marca D2C detectada en la búsqueda
- `marketplace_brand_names`: Marketplace detectado en la búsqueda  
- `d2c_match_type`: Precisión del match (`exact`/`broad`)
- `marketplace_match_type`: Precisión del match (`exact`/`broad`)

#### **Brand Monitoring Específico**
- `is_nuvemshop_tiendanube`: Detección de nuestras marcas (true/false)
- `is_next_evolucion`: Detección de features futuras (true/false)

#### **Search Intent Analysis**
- `non_brand_term`: Término específico detectado
- `non_brand_category`: Categoría de intención (8 categorías)
- `non_brand_match_type`: Precisión del match

### **Clasificación Principal**
- `branded_non_branded`: Clasificación general (branded/nonbranded)

### **Métricas Derivadas**
- `click_through_rate`: CTR calculado automáticamente
- `device`: NULL convertido a 'DESKTOP' automáticamente

---

## 🔍 Capacidades de Inteligencia Competitiva

### **Detección Automática por País**

| **País** | **D2C Platforms** | **Marketplaces** |
|----------|-------------------|------------------|
| **Argentina** | shopify, vtex, magento, prestashop, woocommerce, bigcommerce, commerceup, empretienda, mi negocio personal, tienda neolo | mercado libre, fravega, facebook marketplace, olx, amazon, aliexpress, ebay |
| **Brasil** | shopify, tray, vtex, bagy, iluria, loja integrada, wix | mercado livre, amazon, americanas, magalu, shopee, olx, submarino, casas bahia, netshoes, enjoei, shein, aliexpress |
| **México** | shopify, vtex, magento, prestashop, woocommerce, ecwid, kichink, squarespace, t1paginas, wix, mercadoshops | mercado libre, amazon, liverpool, walmart, elektra, coppel, linio, bodega aurrera, claro shop, shopee, shein, aliexpress, ebay |
| **Chile** | shopify, vtex, prestashop, woocommerce, bsale, jumpseller, apanio, ecwid, kichink, wix, mercadoshops | mercado libre, falabella, ripley, paris, linio, yapo, homecenter, shopee, shein, aliexpress |
| **Colombia** | shopify, vtex, prestashop, woocommerce, dropi, rocketfy, sumerlabs, ecwid, kichink, wix, empretienda, mercadoshops | mercado libre, amazon, falabella, exito, linio, olx, alkosto, homecenter, shopee, shein, aliexpress |
| **Perú** | tiendanube | - |

### **Análisis de Intención No-Branded**

| **Categoría** | **Ejemplos de Términos** | **Insights de Negocio** | **Lógica de Detección** |
|---------------|--------------------------|-------------------------|------------------------|
| **Intention Verbs** | crear, hacer, trabajar, montar, abrir | Alta intención de creación de tienda | Exact match primero, luego CONTAINS |
| **D2C** | tienda, loja, sitio, plataforma, comercio | Búsqueda directa de soluciones D2C | CONTAINS en query |
| **Vendas** | venta, venda, vender | Intención comercial directa | Exact 'venta'/'venda', broad para resto |
| **Dropshipping** | dropshipping | Modelo de negocio específico | CONTAINS 'dropshipping' |
| **Envios** | envío, entrega, shipping, rastreo | Preocupación por logística | CONTAINS múltiples variantes |
| **Ecommerce** | ecommerce, online, virtual, marketplace | Términos generales de industria | CONTAINS múltiples términos |
| **Producto** | produto, roupa, ropa | Búsqueda por categoría | CONTAINS términos de producto |
| **Redes Sociales** | instagram, facebook, tiktok, whatsapp | Integración con social media | CONTAINS nombres de redes |

---

## 🔧 Metodología Técnica

### **Sistema de Macros Automatizadas**
- **get_d2c_brand_detection()**: Detección D2C con 65+ términos
- **get_marketplace_brand_detection()**: Detección Marketplaces  
- **get_nonbranded_terms_detection()**: Clasificación de intención
- **get_country_mapping()**: Mapeo países por site
- **get_date_dimensions()**: Dimensiones temporales

### **Pipeline de Procesamiento**
```
1. SOURCE DATA → Filtros básicos (fecha, país, tipo)
2. INTERMEDIATE → Limpieza y country mapping  
3. BRAND DETECTION → D2C + Marketplace detection
4. NONBRAND DETECTION → Solo si no hay marcas
5. ENRICHMENT → Campos derivados y métricas
6. FINAL OUTPUT → Modelo listo para análisis
```

### **Optimizaciones de Performance**
- **Filtros tempranos** en capa intermediate
- **Materialización table** para consultas rápidas
- **Lógica de prioridad** evita múltiples evaluaciones
- **STRUCT returns** para eficiencia de memoria

---

## 📈 Casos de Uso y Ejemplos

### **Para Marketing Strategy**
```sql
-- Top competidores por país
SELECT country, d2c_brand_names, SUM(impressions) 
FROM marketing_google_search_console_enriched 
WHERE branded_non_branded = 'branded' AND d2c_brand_names IS NOT NULL
GROUP BY country, d2c_brand_names 
ORDER BY SUM(impressions) DESC
```

### **Para Product Marketing**
```sql
-- Detección de búsquedas "Next Evolution"
SELECT search_query, impressions, clicks
FROM marketing_google_search_console_enriched 
WHERE is_next_evolucion = true
ORDER BY impressions DESC
```

### **Para Growth Marketing**
```sql
-- Oportunidades non-branded por categoría
SELECT non_brand_category, COUNT(*) as queries, SUM(impressions)
FROM marketing_google_search_console_enriched 
WHERE branded_non_branded = 'nonbranded'
GROUP BY non_brand_category 
ORDER BY SUM(impressions) DESC
```

---

## 🎯 Ventajas Competitivas

### **Automatización Completa**
- **65+ marcas** monitoreadas automáticamente por país
- **8 categorías** de intención clasificadas por prioridad
- **Match exacto y broad** para máxima cobertura
- **Sistema de prioridades** evita conflictos

### **Granularidad por País**
- Mapeo específico de competidores por mercado
- Términos localizados (México/México, acentos, etc.)
- Sites específicos por región
- Variantes de marca por país

### **Intelligence Accionable**
- Datos listos para analysis sin post-procesamiento
- Campos pre-calculados para dashboards
- Métricas derivadas incluidas (CTR, date dimensions)
- Tests de calidad automáticos

### **Escalabilidad y Mantenimiento**
- **Fácil adición** de nuevos competidores en macros
- **Actualización centralizada** de términos por país
- **Documentación completa** de lógica de negocio
- **Arquitectura modular** para extensiones futuras

---

## 💼 Impacto Esperado

### **Eficiencia Operativa**
- **Reducción 80%** en tiempo manual de competitive analysis
- **Automatización 100%** de brand monitoring
- **Centralización** de insights de búsqueda orgánica
- **Eliminación** de análisis manual repetitivo

### **Strategic Insights**
- **Visibilidad completa** del competitive landscape por país
- **Early detection** de tendencias y oportunidades de mercado
- **Data-driven decisions** para strategy de producto y marketing
- **Monitoring proactivo** de features competitors

### **ROI Proyectado**
- **Identificación proactiva** de threats competitivos
- **Optimización** de content strategy basada en search intent
- **Mejora en targeting** de campaigns pagadas
- **Time-to-insight** reducido de semanas a minutos

---

## 🚀 Próximos Pasos

### **Implementación Técnica**
1. **Validación con datos históricos** (1 semana)
2. **Setup de dashboards** en herramienta de BI (1 semana)
3. **Training del equipo** de Marketing (3 días)
4. **Go-live y monitoreo** inicial (1 semana)

### **Roadmap de Extensiones**
- **Alertas automáticas** para cambios significativos en competencia
- **Integración con herramientas** de Paid Search
- **Expansión a nuevos mercados** (Uruguay, Ecuador)
- **Machine Learning** para predicción de tendencias

---

## 💡 Conclusión

**Este modelo representa una ventaja competitiva significativa al proporcionar intelligence automatizada y sistemática que ningún competidor tiene acceso de forma escalable.**

El sistema transforma datos brutos en insights accionables, eliminando trabajo manual y proporcionando visibilidad completa del landscape competitivo en tiempo real.

---

*Documento generado por el equipo de Data Engineering en colaboración con Marketing Analytics - Noviembre 2024*
