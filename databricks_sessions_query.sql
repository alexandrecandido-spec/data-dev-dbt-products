-- Consulta adaptada de Redshift a Databricks para obtener sessions por country, store_id, date y hour
-- Basada en la consulta original de Redshift proporcionada

SELECT 
    i.country,
    s.store_id,
    
    -- Conversión de timezone adaptada para Databricks (equivalente a CONVERT_TIMEZONE de Redshift)
    CASE 
        WHEN i.country = 'AR' THEN 
            date_trunc('hour', from_utc_timestamp(s.timestamp, 'America/Argentina/Buenos_Aires'))
        WHEN i.country = 'MX' THEN 
            date_trunc('hour', from_utc_timestamp(s.timestamp, 'America/Mexico_City'))
        WHEN i.country = 'BR' THEN 
            date_trunc('hour', from_utc_timestamp(s.timestamp, 'America/Sao_Paulo'))
        WHEN i.country = 'CO' THEN 
            date_trunc('hour', from_utc_timestamp(s.timestamp, 'America/Bogota'))
        ELSE NULL 
    END AS fecha_hora,
    
    -- Extraer date y hour por separado si son necesarios
    CASE 
        WHEN i.country = 'AR' THEN 
            DATE(from_utc_timestamp(s.timestamp, 'America/Argentina/Buenos_Aires'))
        WHEN i.country = 'MX' THEN 
            DATE(from_utc_timestamp(s.timestamp, 'America/Mexico_City'))
        WHEN i.country = 'BR' THEN 
            DATE(from_utc_timestamp(s.timestamp, 'America/Sao_Paulo'))
        WHEN i.country = 'CO' THEN 
            DATE(from_utc_timestamp(s.timestamp, 'America/Bogota'))
        ELSE NULL 
    END AS date,
    
    CASE 
        WHEN i.country = 'AR' THEN 
            HOUR(from_utc_timestamp(s.timestamp, 'America/Argentina/Buenos_Aires'))
        WHEN i.country = 'MX' THEN 
            HOUR(from_utc_timestamp(s.timestamp, 'America/Mexico_City'))
        WHEN i.country = 'BR' THEN 
            HOUR(from_utc_timestamp(s.timestamp, 'America/Sao_Paulo'))
        WHEN i.country = 'CO' THEN 
            HOUR(from_utc_timestamp(s.timestamp, 'America/Bogota'))
        ELSE NULL 
    END AS hour,
    
    COUNT(DISTINCT s.session_id) AS sessions

FROM hive_metastore.moltres.mwp_store_info i
JOIN hive_metastore.storefronts_curated.sessions s ON s.store_id = i.id
WHERE i.state <> 4
    -- Filtro por país (ajustar según necesidad)
    AND i.country IN ('MX')  -- Cambiar por los países deseados: ('AR','MX','BR','CO')
    
    -- Excluir tiendas bloqueadas (equivalente al NOT IN de la query original)
    AND i.id NOT IN (
        SELECT related_id 
        FROM hive_metastore.moltres.mwp_tags 
        WHERE tag IN ('sre-block-store-404', 'sre-block-store-429')
    )
    
    -- Filtros de fechas adaptados (convertir date_id ranges a fechas)
    -- Ejemplo de rangos de fechas basados en la query original:
    AND (
        DATE(s.timestamp) BETWEEN '2023-05-07' AND '2023-05-24'  -- date_id >= 20230507 AND date_id <= 20230524
        OR DATE(s.timestamp) BETWEEN '2023-11-05' AND '2023-12-02'  -- date_id >= 20231105 AND date_id <= 20231202
        OR DATE(s.timestamp) BETWEEN '2024-05-10' AND '2024-06-01'  -- date_id >= 20240510 AND date_id <= 20240601
        OR DATE(s.timestamp) >= '2024-11-01'  -- date_id >= 20241101
    )

GROUP BY i.country, s.store_id, fecha_hora, date, hour
ORDER BY i.country, s.store_id, fecha_hora;

-- COMENTARIOS PARA ADAPTACIÓN:
-- 1. Cambiar 'hive_metastore' por el catálogo correspondiente en tu Databricks
-- 2. Ajustar los esquemas 'moltres' y 'storefronts_curated' según tu configuración
-- 3. Los filtros de fecha pueden necesitar ajustes según los datos disponibles
-- 4. Considera agregar más filtros si es necesario (por ejemplo, filtrar por device, etc.)

-- ALTERNATIVA USANDO MODELOS DBT (si estás ejecutando desde dbt):
/*
FROM {{ source('stg_moltres', 'mwp_store_info') }} i
JOIN {{ source('stg_storefronts', 'sessions') }} s ON s.store_id = i.id
...
FROM {{ source('stg_moltres', 'mwp_tags') }}
*/
