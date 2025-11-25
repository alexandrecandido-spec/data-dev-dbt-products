# Google Search Console - Modelo de Inteligencia Competitiva y Brand Monitoring

## Resumen Ejecutivo

Hemos desarrollado un **modelo avanzado de análisis de Google Search Console** que transforma los datos brutos de búsquedas orgánicas en **inteligencia competitiva accionable** para el equipo de Marketing. Este modelo proporciona visibilidad completa del landscape competitivo y el comportamiento de búsqueda de usuarios potenciales en todos nuestros mercados.

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

## 📊 Estructura de Datos Final

### **Dimensiones Core**
- **Temporales:** Día, Mes, Trimestre, Semana, Año
- **Geográficas:** País (AR, BR, MX, CL, CO, PE) 
- **Técnicas:** Device, Site, Fuente de datos

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

### **Métricas de Performance**
- `impressions`: Impresiones en resultados de búsqueda
- `clicks`: Clicks generados 
- `average_position`: Posición promedio en SERPs
- `click_through_rate`: CTR calculado

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

| **Categoría** | **Ejemplos de Términos** | **Insights de Negocio** |
|---------------|--------------------------|-------------------------|
| **Intention Verbs** | crear, hacer, trabajar, montar, abrir | Alta intención de creación de tienda |
| **D2C** | tienda, loja, sitio, plataforma, comercio | Búsqueda directa de soluciones D2C |
| **Vendas** | venta, venda, vender | Intención comercial directa |
| **Dropshipping** | dropshipping | Modelo de negocio específico |
| **Envios** | envío, entrega, shipping, rastreo | Preocupación por logística |
| **Ecommerce** | ecommerce, online, virtual, marketplace | Términos generales de industria |
| **Producto** | producto, ropa, roupa | Búsqueda por categoría de producto |
| **Redes Sociales** | instagram, facebook, tiktok, whatsapp | Integración con social media |

## 📈 Casos de Uso y Applications

### **Para Marketing Strategy**
- **Competitive Analysis:** ¿Qué competidores están ganando visibility en búsquedas orgánicas?
- **Market Opportunity:** ¿Qué términos no-branded tienen más volumen sin competencia directa?
- **Brand Health:** ¿Cómo evoluciona nuestro share of voice vs competidores?

### **Para Product Marketing**
- **Feature Discovery:** Detección temprana de búsquedas relacionadas con "Next" y "Evolution"
- **Market Demand:** ¿Qué funcionalidades buscan más los usuarios por país?
- **Competitive Intelligence:** ¿Qué features de competidores generan más interés?

### **Para Growth Marketing**
- **SEO Strategy:** Identificación de keywords de alta intención con baja competencia
- **Content Strategy:** Qué contenido crear basado en intenciones de búsqueda detectadas
- **Paid Search:** Insights para bidding strategy en términos competitivos

### **Para Business Intelligence**
- **Market Sizing:** Volumen de búsquedas por categoría y país
- **Seasonal Trends:** Patrones temporales de búsqueda por competidor/categoría  
- **Geographic Insights:** Performance relativo por mercado

## 🎯 Ventajas Competitivas

### **Automatización Completa**
- **65+ marcas** monitoreadas automáticamente
- **8 categorías** de intención clasificadas automáticamente
- **Match exacto y broad** para máxima cobertura

### **Granularidad por País**
- Mapeo específico de competidores por mercado
- Términos localizados (México/México, español/portugués)
- Sites específicos por región

### **Intelligence Accionable**
- Datos listos para analysis sin post-procesamiento
- Campos pre-calculados para dashboards
- Métricas derivadas incluidas (CTR, etc.)

### **Escalabilidad y Mantenimiento**
- Fácil adición de nuevos competidores
- Actualización centralizada de términos
- Documentación completa de lógica de negocio

## 📊 Ejemplo de Insights Obtenibles

### **Competitive Analysis**
```sql
-- Top 10 competidores por impressions en Argentina
SELECT d2c_brand_names, SUM(impressions) 
FROM marketing_google_search_console_enriched 
WHERE country = 'AR' AND branded_non_branded = 'branded'
GROUP BY d2c_brand_names 
ORDER BY SUM(impressions) DESC LIMIT 10
```

### **Market Opportunity**
```sql
-- Términos non-branded con mayor volumen sin cobertura nuestra
SELECT non_brand_term, non_brand_category, SUM(impressions)
FROM marketing_google_search_console_enriched 
WHERE branded_non_branded = 'nonbranded' 
  AND is_nuvemshop_tiendanube = false
GROUP BY non_brand_term, non_brand_category 
ORDER BY SUM(impressions) DESC
```

### **Brand Health**
```sql
-- Evolución de share of voice Tiendanube vs competencia
SELECT date_month, 
       CASE WHEN is_nuvemshop_tiendanube THEN 'Tiendanube' ELSE 'Competencia' END,
       SUM(impressions)
FROM marketing_google_search_console_enriched 
WHERE branded_non_branded = 'branded'
GROUP BY date_month, CASE WHEN is_nuvemshop_tiendanube THEN 'Tiendanube' ELSE 'Competencia' END
```

## 🚀 Implementación y Timeline

### **Status Actual**
- ✅ Modelo de datos definido y documentado
- ✅ Lógica de clasificación implementada
- ✅ Macros de detección automática creadas
- ✅ Tests de calidad de datos configurados

### **Próximos Pasos**
1. **Validación** con datos históricos (1 semana)
2. **Dashboard setup** en herramienta de BI preferida (1 semana)  
3. **Training** del equipo de Marketing (3 días)
4. **Go-live** y monitoreo inicial (1 semana)

## 💼 Impacto Esperado

### **Eficiencia Operativa**
- **Reducción 80%** en tiempo manual de competitive analysis
- **Automatización 100%** de brand monitoring
- **Centralización** de insights de búsqueda orgánica

### **Strategic Insights**
- **Visibilidad completa** del competitive landscape por país
- **Early detection** de tendencias y oportunidades de mercado
- **Data-driven decisions** para strategy de producto y marketing

### **ROI Proyectado**
- **Identificación proactiva** de threats competitivos
- **Optimización** de content strategy basada en search intent
- **Mejora en targeting** de campaigns pagadas

---

*Este modelo representa una **ventaja competitiva significativa** al proporcionar intelligence automatizada que ningún competidor tiene acceso de forma sistemática y escalable.*
