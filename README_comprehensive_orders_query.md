# Query Comprensiva de Órdenes - Documentación

Esta query SQL proporciona una vista completa de las órdenes con toda la información solicitada para análisis de negocio.

## Campos Incluidos

### Información Básica de la Orden
- **store_id**: ID único de la tienda
- **order_id**: ID único de la orden
- **date**: Fecha de la orden (completed_at)
- **hour**: Hora de completación de la orden (0-23)
- **device**: Tipo de dispositivo (computer, phone, other)

### Marketing y Origen
- **source**: Fuente de tráfico (UTM source, referrer, etc.)
- **social_network**: Red social identificada (instagram, facebook, tiktok, etc.)

### Ubicación Geográfica
- **province**: Provincia de la tienda
- **city**: Ciudad de la tienda  
- **region**: Región de la tienda
- **province_shipping**: Provincia de envío

### Información de Envío
- **shipping_method**: Método de envío utilizado
- **is_free_shipping**: Indicador booleano de envío gratis

### Promociones y Descuentos
- **has_promotion**: Indicador de si la orden tiene promociones aplicadas

### Información de Pago
- **installments**: Número de cuotas (0 si no aplica)
- **payment_method**: Método de pago específico
- **payment_provider**: Proveedor de pago (gateway)

### Información de la Tienda
- **store_name**: Nombre/dominio de la tienda
- **is_success**: Indicador de orden exitosa (completada, pagada, no cancelada)

## Fuentes de Datos

### Tablas Principales
1. **`orders__mwp_orders`**: Tabla base de órdenes
2. **`product_social_order_source`**: Información de fuentes sociales y marketing
3. **`company_metrics_merchant_info`**: Información de comerciantes y ubicación
4. **`dim_location_state`**: Dimensión de estados/provincias
5. **`mwp_apps`**: Información de aplicaciones de pago
6. **`mwp_shipping_carriers`**: Información de transportistas

### Lógica de Negocio Implementada

#### Free Shipping
```sql
CASE 
  WHEN shipping_cost = 0 OR shipping_cost IS NULL 
  THEN TRUE 
  ELSE FALSE 
END AS is_free_shipping
```

#### Success Status
```sql
CASE  
  WHEN status != 'cancelled' 
    AND payment_status = 'paid' 
    AND completed_at IS NOT NULL 
  THEN TRUE 
  ELSE FALSE 
END AS is_success
```

#### Social Network Classification
```sql
CASE 
  WHEN source_name IN ('instagram', 'facebook', 'tiktok', 'twitter', 'pinterest', 'meta') 
  THEN source_name
  WHEN source_name = 'whatsapp' THEN 'whatsapp'
  WHEN http_referrer LIKE '%linkedin%' THEN 'linkedin'
  WHEN http_referrer LIKE '%youtube%' THEN 'youtube'
  ELSE 'other'
END AS social_network
```

#### Promotion Detection
```sql
CASE 
  WHEN total < (total_in_usd * 0.9) THEN TRUE  -- Descuento significativo
  WHEN shipping_cost = 0 AND shipping_method != 'pickup' THEN TRUE  -- Envío gratis promocional
  ELSE FALSE
END AS has_promotion
```

## Uso de la Query

### Filtros Disponibles
- **Rango de fechas**: Modificar `WHERE bo.completed_at >= '2024-01-01'`
- **Solo órdenes exitosas**: Comentar/descomentar `AND bo.is_success = TRUE`
- **País específico**: Agregar filtro en store_info
- **Método de pago**: Filtrar por payment_provider o payment_method

### Ejemplos de Modificación

#### Para obtener todas las órdenes (incluyendo fallidas):
```sql
-- Comentar esta línea:
-- AND bo.is_success = TRUE
```

#### Para filtrar por país específico:
```sql
WHERE bo.completed_at >= '2024-01-01'
  AND si.country_code = 'BR'  -- Solo Brasil
```

#### Para analizar un método de pago específico:
```sql
WHERE bo.completed_at >= '2024-01-01'
  AND pmi.payment_provider = 'mercadopago'
```

## Consideraciones de Performance

1. **Particionamiento**: La query usa `year_month_day_code` para optimización
2. **Índices**: Asegurar índices en `order_id`, `store_id`, `completed_at`
3. **Rango de fechas**: Siempre filtrar por fecha para mejorar performance
4. **Joins**: Los LEFT JOINs permiten datos faltantes sin eliminar registros

## Campos Adicionales Incluidos

Para análisis adicional, la query incluye:
- **total**: Monto total de la orden
- **total_in_usd**: Monto en USD
- **currency**: Moneda de la transacción
- **storefront**: Canal de venta (mobile, store, api, etc.)
- **country**: País de la tienda
- **store_segment**: Segmento comercial de la tienda
- **store_vertical**: Vertical de negocio de la tienda
- **order_completed_timestamp**: Timestamp completo de finalización

## Notas Importantes

- La detección de promociones es heurística y puede requerir ajustes según reglas de negocio específicas
- Los datos de redes sociales dependen de la calidad de los parámetros UTM y referrers
- Algunos campos pueden estar vacíos (NULL) si la información no está disponible en las fuentes
- La query está optimizada para órdenes completadas; ajustar filtros según necesidades específicas
