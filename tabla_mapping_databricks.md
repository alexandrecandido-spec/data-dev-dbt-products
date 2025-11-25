# Mapeo de Referencias dbt a Tablas Databricks (hive_metastore)

Esta documentación muestra cómo se mapean las referencias dbt del modelo `company_metrics_paid_orders` a las tablas reales en Databricks usando `hive_metastore`.

## Mapeo de Tablas

### Referencias dbt → Databricks

| Referencia dbt | Tabla Databricks | Esquema Original | Descripción |
|----------------|------------------|------------------|-------------|
| `{{ ref('orders__mwp_orders') }}` | `hive_metastore.orders.mwp_orders` | `orders` | Tabla principal de órdenes |
| `{{ ref('moltres__mwp_store_info') }}` | `hive_metastore.moltres.mwp_store_info` | `moltres` | Información de tiendas |
| `{{ source('int_moltres', 'mwp_tags') }}` | `hive_metastore.moltres.mwp_tags` | `moltres` | Tags de tiendas |
| `{{ source('int_moltres', 'mwp_apps') }}` | `hive_metastore.moltres.mwp_apps` | `moltres` | Apps/gateways de pago |
| `{{ source('int_moltres', 'mwp_shipping_carriers') }}` | `hive_metastore.moltres.mwp_shipping_carriers` | `moltres` | Transportistas |
| `{{ ref('company_metrics_products_per_order') }}` | `hive_metastore.orders.mwp_order_products` | `orders` | Productos por orden |
| `orders.mwp_orders_logging` | `hive_metastore.orders.mwp_orders_logging` | `orders` | Log de estados de órdenes |
| `{{ source('int_third_party', 'finance_exchange_rate_ars_to_usd') }}` | `hive_metastore.third_party.finance_exchange_rate_ars_to_usd` | `third_party` | Tasas de cambio ARS |

## Estructura por Esquemas

### Esquema `orders`
```sql
hive_metastore.orders.mwp_orders              -- Órdenes principales
hive_metastore.orders.mwp_order_products      -- Productos por orden  
hive_metastore.orders.mwp_orders_logging      -- Estados de órdenes
```

### Esquema `moltres`
```sql
hive_metastore.moltres.mwp_store_info         -- Información de tiendas
hive_metastore.moltres.mwp_tags               -- Tags de tiendas
hive_metastore.moltres.mwp_apps               -- Apps de pago
hive_metastore.moltres.mwp_shipping_carriers  -- Transportistas
```

### Esquema `third_party`
```sql
hive_metastore.third_party.finance_exchange_rate_ars_to_usd  -- Tasas ARS
```

## Configuración en Databricks

### Acceso a Tablas
Para usar estas tablas en Databricks, asegúrate de tener permisos de lectura en:
- `hive_metastore.orders.*`
- `hive_metastore.moltres.*`  
- `hive_metastore.third_party.*`

### Verificación de Tablas
Puedes verificar que las tablas existen ejecutando:

```sql
-- Verificar esquemas disponibles
SHOW SCHEMAS IN hive_metastore;

-- Verificar tablas en orders
SHOW TABLES IN hive_metastore.orders;

-- Verificar tablas en moltres  
SHOW TABLES IN hive_metastore.moltres;

-- Verificar tablas en third_party
SHOW TABLES IN hive_metastore.third_party;
```

### Estructura de Datos
Para verificar la estructura de una tabla específica:

```sql
-- Describir estructura de órdenes
DESCRIBE hive_metastore.orders.mwp_orders;

-- Ver primeras filas
SELECT * FROM hive_metastore.orders.mwp_orders LIMIT 5;
```

## Transformaciones dbt Replicadas

### CTEs en la Query Plana

1. **`blocked_stores`** - Replica filtros de tiendas bloqueadas
2. **`payment_date`** - Replica obtención de fechas de pago
3. **`base_orders`** - Replica modelo staging `orders__mwp_orders`
4. **`store_info`** - Replica modelo staging `moltres__mwp_store_info`
5. **`ars_exchange_rate`** - Replica tasas de cambio ARS
6. **`orders_exchange_rates`** - Replica cálculo de tasas para otras monedas
7. **`all_exchange_rates`** - Combina todas las tasas de cambio
8. **`enriched_orders`** - Replica modelo intermedio con lógica de negocio
9. **`products_per_order`** - Replica aggregación de productos

## Consideraciones de Performance

### Particionamiento
Las tablas grandes como `mwp_orders` pueden estar particionadas. Verifica con:

```sql
SHOW PARTITIONS hive_metastore.orders.mwp_orders;
```

### Filtros Recomendados
Siempre usar filtros temporales para mejorar performance:

```sql
-- En base_orders CTE
WHERE completed_at >= '2024-01-01'
  AND total_in_usd <= 10000 
  AND total_in_usd >= 0
```

### Índices y Statistics
Verificar si hay statistics disponibles:

```sql
ANALYZE TABLE hive_metastore.orders.mwp_orders COMPUTE STATISTICS;
```

## Diferencias con dbt

### Sin Macros
- `{{ get_existing_data() }}` - Removido (no aplicable en query única)
- `{{ config() }}` - Removido (configuración dbt)
- `{{ is_incremental() }}` - Convertido a filtros estáticos

### Sin Post-hooks
Los post-hooks de dbt no se ejecutan:
```sql
-- Estos DELETE automáticos no ocurren:
-- DELETE FROM table WHERE cancelled orders
-- DELETE FROM table WHERE test stores
```

### Referencias Dinámicas
Las referencias dinámicas se vuelven estáticas:
```sql
-- dbt: {{ ref('orders__mwp_orders') }}
-- Databricks: hive_metastore.orders.mwp_orders
```

## Troubleshooting

### Error: Schema not found
```sql
-- Verificar que el esquema existe
SHOW SCHEMAS IN hive_metastore LIKE '*orders*';
```

### Error: Table not found  
```sql
-- Verificar nombre exacto de tabla
SHOW TABLES IN hive_metastore.orders LIKE '*mwp_orders*';
```

### Performance Issues
- Reducir rango de fechas en `WHERE completed_at >= 'YYYY-MM-DD'`
- Usar `LIMIT` para testing inicial
- Verificar particionamiento de tablas grandes

### Permisos
```sql
-- Verificar permisos
SHOW GRANT ON SCHEMA hive_metastore.orders;
```
