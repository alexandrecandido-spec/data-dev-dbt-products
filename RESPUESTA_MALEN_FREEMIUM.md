# Respuesta para Malen - Casos de Freemium

## Pregunta
> "En los casos de freemium, donde por default ya vienen instalados los medios de pago y envío, ¿cómo se considera?"

## Respuesta

Hola Malen! 👋

Excelente pregunta. Te explico cómo funcionan los modelos actualmente y qué necesitamos verificar:

### 📊 **Cómo funcionan los modelos actualmente:**

#### **1. Payments (`s__product_marketing__payments__ref`)**
- **Lógica:** Detecta si existe al menos un evento `PaymentProviderRegistered` en la tabla `journal_payment_provider` para la tienda
- **Resultado:** Si hay evento → `config_payment = 1`, si no → `config_payment = 0`

#### **2. Shipping (`s__product_marketing__shipping__ref`)**
- **Lógica:** Detecta si existe al menos un carrier activo (`status = 1`) con opciones activas en `mwp_shipping_carriers` y `mwp_shipping_carriers_options`
- **Resultado:** Si hay carrier activo → `config_shipping = 1`, si no → `config_shipping = 0`

### ❓ **Lo que necesitamos verificar:**

Para que los modelos funcionen correctamente con freemium, necesitamos confirmar:

1. **Payments:**
   - ¿Cuando se crea una tienda freemium, se registra automáticamente un evento `PaymentProviderRegistered` en `journal_payment_provider`?
   - Si **SÍ** → Las tiendas freemium aparecerán como `config_payment = 1` desde el inicio ✅
   - Si **NO** → Aparecerán como `config_payment = 0` aunque técnicamente tengan pagos instalados ❌

2. **Shipping:**
   - ¿Cuando se crea una tienda freemium, se crean automáticamente carriers con `status = 1` en `mwp_shipping_carriers`?
   - Si **SÍ** → Las tiendas freemium aparecerán como `config_shipping = 1` desde el inicio ✅
   - Si **NO** → Aparecerán como `config_shipping = 0` aunque técnicamente tengan shipping instalado ❌

### 🔍 **Cómo verificar:**

Podríamos hacer una consulta rápida para verificar:

```sql
-- Verificar payments en freemium
SELECT 
    s.store_id,
    s.created_at,
    pg.grupo AS plan_group,
    COUNT(DISTINCT jpps.storeId) AS payment_events_count,
    MIN(jpps.utcDateTime) AS first_payment_event
FROM `data_products_dev`.`testing_merchant`.`s__attributes__store_core__ref` s
LEFT JOIN `operations_grouping_plans` pg ON s.plan_id = pg.plan
LEFT JOIN `hive_metastore`.`payments`.`journal_payment_provider` jpps
    ON CAST(jpps.storeId AS BIGINT) = s.store_id
    AND ARRAY_CONTAINS(jpps.event_tg, 'PaymentProviderRegistered')
WHERE pg.grupo = 'freemium'
    AND s.created_at >= '2024-01-01'
GROUP BY s.store_id, s.created_at, pg.grupo
LIMIT 100;

-- Verificar shipping en freemium
SELECT 
    s.store_id,
    s.created_at,
    pg.grupo AS plan_group,
    COUNT(DISTINCT sc.id) AS active_carriers_count,
    MIN(sc.created_at) AS first_carrier_date
FROM `data_products_dev`.`testing_merchant`.`s__attributes__store_core__ref` s
LEFT JOIN `operations_grouping_plans` pg ON s.plan_id = pg.plan
LEFT JOIN `hive_metastore`.`moltres`.`mwp_shipping_carriers` sc
    ON sc.store_id = s.store_id
    AND sc.status = 1
    AND sc.deleted_at IS NULL
LEFT JOIN `hive_metastore`.`moltres`.`mwp_shipping_carriers_options` sco
    ON sco.carrier_id = sc.id
    AND sco.status = 1
    AND sco.deleted_at IS NULL
WHERE pg.grupo = 'freemium'
    AND s.created_at >= '2024-01-01'
GROUP BY s.store_id, s.created_at, pg.grupo
LIMIT 100;
```

### 💡 **Posibles soluciones si NO se registran automáticamente:**

Si verificamos que en freemium **NO** se registran los eventos/carriers automáticamente, podríamos:

1. **Opción A:** Ajustar la lógica de los modelos para considerar el plan `freemium` como "configurado por defecto"
2. **Opción B:** Coordinar con el equipo de producto para que se registren los eventos/carriers automáticamente al crear tiendas freemium
3. **Opción C:** Crear una lógica híbrida que considere tanto eventos/carriers como el plan freemium

### 📝 **Próximos pasos:**

1. Verificar con el equipo de producto si en freemium se registran automáticamente los eventos/carriers
2. Ejecutar las consultas de verificación para ver el comportamiento real
3. Decidir si necesitamos ajustar la lógica de los modelos

¿Te parece bien si primero verificamos con el equipo de producto o prefieres que ejecute las consultas primero para ver qué está pasando en la práctica?

---

**Contacto:** jhu.boggio@tiendanube.com

