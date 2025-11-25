# Consulta de Sessions en Databricks - Adaptación desde Redshift

## 📋 Descripción

Este documento explica la adaptación de una consulta de Redshift a Databricks para obtener sesiones agrupadas por país, tienda, fecha y hora.

## 🔄 Principales Diferencias entre Redshift y Databricks

### 1. Conversión de Timezone

#### Redshift:
```sql
CONVERT_TIMEZONE('UTC', 'America/Argentina/Buenos_Aires', timestamp)
```

#### Databricks:
```sql
from_utc_timestamp(timestamp, 'America/Argentina/Buenos_Aires')
```

### 2. Fuentes de Datos

#### Original (Redshift):
- `tiendanube.mwp_store_info` 
- `storefronts.sessions`
- `tiendanube.mwp_tags`

#### Adaptado (Databricks):
- `hive_metastore.moltres.mwp_store_info`
- `hive_metastore.storefronts_curated.sessions`
- `hive_metastore.moltres.mwp_tags`

### 3. Filtros de Fecha

#### Original (Redshift):
```sql
date_id >= 20230507 AND date_id <= 20230524
```

#### Adaptado (Databricks):
```sql
DATE(s.timestamp) BETWEEN '2023-05-07' AND '2023-05-24'
```

## 📊 Campos de Salida

La consulta devuelve los siguientes campos:

| Campo | Descripción | Tipo |
|-------|-------------|------|
| `country` | País de la tienda | STRING |
| `store_id` | ID único de la tienda | INTEGER |
| `fecha_hora` | Timestamp truncado por hora (timezone local) | TIMESTAMP |
| `date` | Fecha (timezone local) | DATE |
| `hour` | Hora del día (timezone local) | INTEGER |
| `sessions` | Número de sesiones únicas | BIGINT |

## ⚙️ Configuraciones Necesarias

### 1. Catálogo y Esquemas
Ajustar según tu configuración:
```sql
-- Cambiar 'hive_metastore' por tu catálogo
-- Verificar esquemas 'moltres' y 'storefronts_curated'
```

### 2. Países Soportados
La consulta maneja conversión de timezone para:
- **AR**: `America/Argentina/Buenos_Aires`
- **MX**: `America/Mexico_City`
- **BR**: `America/Sao_Paulo`
- **CO**: `America/Bogota`

### 3. Filtros de Fecha
Actualizar los rangos según tus necesidades:
```sql
AND (
    DATE(s.timestamp) BETWEEN '2023-05-07' AND '2023-05-24'
    OR DATE(s.timestamp) BETWEEN '2023-11-05' AND '2023-12-02'
    -- Agregar más rangos según necesidad
)
```

## 🛠️ Alternativas de Implementación

### Opción 1: Consulta Directa en SQL
Usar el archivo `databricks_sessions_query.sql` directamente en Databricks.

### Opción 2: Modelo dbt
Crear un modelo dbt usando las fuentes definidas:

```sql
FROM {{ source('stg_moltres', 'mwp_store_info') }} i
JOIN {{ source('stg_storefronts', 'sessions') }} s ON s.store_id = i.id
WHERE i.id NOT IN (
    SELECT related_id 
    FROM {{ source('stg_moltres', 'mwp_tags') }}
    WHERE tag IN ('sre-block-store-404', 'sre-block-store-429')
)
```

### Opción 3: Usar Modelo Existente
Aprovechar el modelo `storefronts_curated__sessions` que ya procesa las sesiones:

```sql
FROM {{ ref('storefronts_curated__sessions') }} s
JOIN {{ ref('moltres__mwp_store_info') }} i ON s.store_id = i.store_id
```

## 🚨 Consideraciones Importantes

### 1. Performance
- Considera particionar por fecha para mejorar performance
- Los filtros de país y fecha ayudan a reducir el volumen de datos

### 2. Datos Faltantes
- Tiendas sin país definido retornarán NULL en fecha_hora
- Sesiones sin timestamp válido se excluirán automáticamente

### 3. Tiendas Bloqueadas
- Se excluyen automáticamente tiendas con tags de bloqueo (`sre-block-store-404`, `sre-block-store-429`)
- Se excluyen tiendas con `state = 4`

## 🔍 Ejemplos de Uso

### Sesiones por hora en Argentina
```sql
-- Filtrar solo Argentina y últimos 30 días
WHERE i.country = 'AR'
AND DATE(s.timestamp) >= CURRENT_DATE - 30
```

### Sesiones agregadas por día
```sql
-- Cambiar GROUP BY para agrupar por día en lugar de hora
GROUP BY i.country, s.store_id, 
    DATE(from_utc_timestamp(s.timestamp, 'America/Argentina/Buenos_Aires'))
```

### Top tiendas por sesiones
```sql
-- Agregar ORDER BY para ver las tiendas más activas
ORDER BY sessions DESC
LIMIT 100
```
