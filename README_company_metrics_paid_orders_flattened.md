# Company Metrics Paid Orders - Query Plana para Databricks

Esta query SQL replica exactamente la funcionalidad del modelo dbt `company_metrics_paid_orders` pero en formato "aplanado" para ejecutar directamente en Databricks sin dependencias de dbt.

## ¿Qué hace esta query?

La query combina información de múltiples fuentes para crear una vista comprensiva de las órdenes pagadas, incluyendo:

- **Información básica de órdenes**: ID, tienda, fechas, montos
- **Información de pago**: Gateway, método, cuotas, estado
- **Información de envío**: Método, costo, opciones
- **Información de la tienda**: País, segmento, plan, estado de pago
- **Conversiones de moneda**: Montos en USD y moneda local
- **Productos por orden**: Cantidad total de productos
- **Auditoría y metadata**: Campos de trazabilidad

## Estructura de la Query

### 1. CTEs (Common Table Expressions)

#### `blocked_stores`
- **Propósito**: Identifica tiendas bloqueadas por tags específicos
- **Fuente**: `moltres.mwp_tags`
- **Filtros**: Tags 'sre-block-store-429' o 'sre-block-store-404'

#### `payment_date`
- **Propósito**: Obtiene la fecha de pago real de cada orden
- **Fuente**: `orders.mwp_orders_logging`
- **Lógica**: MAX de happened_at donde data_2 = 'paid'

#### `base_orders`
- **Propósito**: Replica la tabla staging `orders__mwp_orders`
- **Fuente**: `orders.mwp_orders`
- **Transformaciones**:
  - Normalización de device_type
  - Cálculo de is_paid_order
  - Generación de year_month_day_code

#### `store_info`
- **Propósito**: Replica la tabla staging `moltres__mwp_store_info`
- **Fuente**: `moltres.mwp_store_info`
- **Transformaciones**:
  - Identificación de tiendas bloqueadas
  - Filtrado de tiendas con state != 4

#### `ars_exchange_rate` y `orders_exchange_rates`
- **Propósito**: Replica el modelo `finance_exchange_rate`
- **Fuentes**: 
  - `third_party.finance_exchange_rate_ars_to_usd` (para ARS)
  - Calculado desde órdenes (para otras monedas)
- **Lógica**: Tasas de cambio directas e indirectas

#### `enriched_orders`
- **Propósito**: Replica el modelo intermedio `_int_company_metrics_paid_orders__get_store_info`
- **Transformaciones**:
  - Cálculo de montos en diferentes monedas
  - Clasificación de platform_type
  - Determinación de store_status
  - Normalización de payment y shipping methods

#### `products_per_order`
- **Propósito**: Replica `company_metrics_products_per_order`
- **Fuente**: `orders.mwp_order_products`
- **Lógica**: Suma de cantidad por order_id (excluyendo eliminados)

### 2. Query Principal

Combina todos los CTEs para producir el resultado final que replica exactamente `company_metrics_paid_orders`.

## Tablas Utilizadas

### Esquema `orders` (Databricks)
- `hive_metastore.orders.mwp_orders` - Órdenes principales
- `hive_metastore.orders.mwp_order_products` - Productos por orden
- `hive_metastore.orders.mwp_orders_logging` - Log de estados de órdenes

### Esquema `moltres` (Databricks)
- `hive_metastore.moltres.mwp_store_info` - Información de tiendas
- `hive_metastore.moltres.mwp_tags` - Tags de tiendas
- `hive_metastore.moltres.mwp_apps` - Aplicaciones/gateways de pago
- `hive_metastore.moltres.mwp_shipping_carriers` - Transportistas

### Esquema `third_party` (Databricks)
- `hive_metastore.third_party.finance_exchange_rate_ars_to_usd` - Tasas de cambio ARS

## Campos de Salida

| Campo | Descripción | Tipo |
|-------|-------------|------|
| `id` | ID único de la orden | BIGINT |
| `store_id` | ID de la tienda | BIGINT |
| `country` | País de la tienda | STRING |
| `completed_at` | Fecha de completación | TIMESTAMP |
| `gateway` | Gateway de pago | STRING |
| `shipping_method` | Método de envío | STRING |
| `storefront` | Canal de venta | STRING |
| `currency` | Moneda original | STRING |
| `country_currency` | Moneda esperada del país | STRING |
| `shipping_cost` | Costo de envío | DECIMAL |
| `total_in_usd` | Total en USD | DECIMAL |
| `total` | Total en moneda local | DECIMAL |
| `gateway_integration_type` | Tipo de integración | STRING |
| `shipping_option` | Opción de envío | STRING |
| `shipping_pickup_type` | Tipo de pickup | STRING |
| `shipping_province` | Provincia de envío | STRING |
| `gateway_installments` | Número de cuotas | INT |
| `gateway_method` | Método específico del gateway | STRING |
| `contact_email` | Email del cliente | STRING |
| `paid_at` | Fecha real de pago | TIMESTAMP |
| `store_status` | Estado de la tienda | STRING |
| `payment` | Proveedor de pago normalizado | STRING |
| `shipping` | Método de envío normalizado | STRING |
| `platform_type` | Tipo de plataforma (on/off) | STRING |
| `product_quantity` | Cantidad total de productos | INT |
| `year_month_day_code` | Código de partición | INT |
| `is_foreign_currency` | Indicador de moneda extranjera | BOOLEAN |

## Lógica de Negocio Implementada

### Clasificación de Store Status
```sql
CASE
    WHEN churned_at IS NULL AND first_payment IS NOT NULL THEN 'Paying'
    WHEN first_payment IS NOT NULL THEN 'Churned'
    ELSE 'Non activated / Trial'
END
```

### Clasificación de Platform Type
```sql
CASE
    WHEN storefront IN ('mobile', 'store', 'form', 'social', 'pos') 
         OR (storefront = 'api' AND app_id = 12217) THEN 'on'
    ELSE 'off'
END
```

### Conversión de Moneda
- **total_in_usd_billing**: `total / direct_exchange_rate`
- **total_in_local_currency**: Lógica compleja basada en país y moneda

### Filtros Aplicados
- Solo órdenes pagadas (`is_paid_order = TRUE`)
- Excluye storefront 'permalink'
- Excluye tiendas bloqueadas
- Solo órdenes con fecha < CURRENT_DATE()
- Desde 2018-01-01

## Uso en Databricks

### Verificación Previa
Antes de ejecutar la query, verifica que tienes acceso a las tablas:

```sql
-- Verificar esquemas disponibles
SHOW SCHEMAS IN hive_metastore;

-- Verificar tablas específicas
SHOW TABLES IN hive_metastore.orders;
SHOW TABLES IN hive_metastore.moltres;
SHOW TABLES IN hive_metastore.third_party;
```

### Ejecución Básica
```sql
-- Ejecutar la query completa tal como está
-- La query ya incluye todas las referencias hive_metastore
```

### Filtros Adicionales Sugeridos

#### Por Rango de Fechas
```sql
-- Agregar al WHERE final:
AND orders.completed_at >= '2024-01-01'
AND orders.completed_at < '2024-12-31'
```

#### Por País Específico
```sql
-- Agregar al WHERE final:
AND orders.country = 'BR'  -- Brasil
-- o AND orders.country IN ('BR', 'AR', 'MX')
```

#### Por Gateway de Pago
```sql
-- Agregar al WHERE final:
AND orders.payment = 'mercadopago'
```

#### Solo Tiendas Activas
```sql
-- Agregar al WHERE final:
AND orders.store_status = 'Paying'
```

## Optimizaciones de Performance

### Particionamiento
- La query usa `year_month_day_code` para particionamiento
- Siempre filtrar por fecha para mejor performance

### Índices Recomendados
- `orders.mwp_orders`: índice en `completed_at`, `store_id`
- `moltres.mwp_store_info`: índice en `id`
- `orders.mwp_order_products`: índice en `order_id`

### Límites de Datos
```sql
-- Para testing, agregar LIMIT:
ORDER BY orders.completed_at DESC
LIMIT 10000
```

## Diferencias con el Modelo dbt Original

1. **Sin incremental**: Esta query no maneja lógica incremental
2. **Sin post-hooks**: No ejecuta DELETE statements automáticos
3. **Sin existing_data**: No maneja auditoría de registros existentes
4. **Filtros estáticos**: Los filtros condicionales de dbt están convertidos a estáticos

## Validación

Para validar que la query produce los mismos resultados:

```sql
-- Comparar conteos por país
SELECT country, COUNT(*) as orden_count
FROM (QUERY_RESULTADO)
GROUP BY country
ORDER BY orden_count DESC;

-- Comparar totales por moneda
SELECT currency, SUM(total_in_usd) as total_usd
FROM (QUERY_RESULTADO) 
GROUP BY currency
ORDER BY total_usd DESC;
```

## Troubleshooting

### Error: Table not found
- Verificar que los esquemas `orders`, `moltres`, `third_party` existen
- Ajustar nombres de esquemas según tu entorno Databricks

### Performance lenta
- Agregar filtros de fecha más restrictivos
- Usar LIMIT para testing
- Verificar particionamiento de tablas

### Datos faltantes
- Verificar que `third_party.finance_exchange_rate_ars_to_usd` existe
- Algunos LEFT JOINs pueden resultar en NULLs esperados
