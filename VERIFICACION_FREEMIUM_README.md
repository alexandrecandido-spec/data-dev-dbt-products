# Verificación de Comportamiento Freemium

## 📋 Objetivo

Verificar si las tiendas freemium tienen automáticamente registrados:
1. **Eventos de Payments**: Eventos `PaymentProviderRegistered` en `journal_payment_provider`
2. **Carriers de Shipping**: Carriers activos en `mwp_shipping_carriers` con opciones activas

## 🔍 Consultas Incluidas

El archivo `VERIFICACION_FREEMIUM.sql` contiene 5 consultas:

### 1. **Consulta 1: Detalle de Payments en Freemium**
- Muestra tiendas freemium individuales con información sobre eventos de payments
- Incluye: `store_id`, fecha de creación, si tiene evento de pago, fecha del primer evento, días entre creación y primer evento
- **Límite:** 100 tiendas (más recientes primero)

### 2. **Consulta 2: Resumen de Payments en Freemium**
- Estadísticas agregadas: total de tiendas freemium, cuántas tienen eventos, porcentaje
- **Resultado esperado:** Una fila con estadísticas generales

### 3. **Consulta 3: Detalle de Shipping en Freemium**
- Muestra tiendas freemium individuales con información sobre carriers activos
- Incluye: `store_id`, fecha de creación, si tiene carrier activo, fecha del primer carrier, cantidad de carriers
- **Límite:** 100 tiendas (más recientes primero)

### 4. **Consulta 4: Resumen de Shipping en Freemium**
- Estadísticas agregadas: total de tiendas freemium, cuántas tienen carriers activos, porcentaje
- **Resultado esperado:** Una fila con estadísticas generales

### 5. **Consulta 5: Comparación Freemium vs Trial/Paid**
- Compara el comportamiento entre freemium y otros planes (ej: plan-a)
- Útil para entender si hay diferencias en el comportamiento

## 🚀 Cómo Ejecutar

### Opción 1: Databricks SQL Editor
1. Abre Databricks SQL Editor
2. Copia y pega cada consulta individualmente
3. Ejecuta y revisa los resultados

### Opción 2: Databricks Notebook
1. Crea un nuevo notebook en Databricks
2. Copia el contenido de `VERIFICACION_FREEMIUM.sql`
3. Separa cada consulta en celdas diferentes (opcional)
4. Ejecuta celda por celda

### Opción 3: dbt (compilando las consultas)
```bash
cd data-dev-dbt-products/nubeproduct
# Las consultas usan referencias directas a tablas, no usan dbt refs
# Por lo tanto, es mejor ejecutarlas directamente en Databricks
```

## 📊 Interpretación de Resultados

### Escenario Ideal (Freemium funciona correctamente)
- **Consulta 2 (Payments):** `percentage_with_payment_events` debería ser **cercano a 100%**
- **Consulta 4 (Shipping):** `percentage_with_active_carriers` debería ser **cercano a 100%**
- **Consulta 1 y 3:** `days_between_store_creation_and_first_*` debería ser **0 o muy bajo** (0-1 días)

### Escenario Problemático (Freemium NO funciona automáticamente)
- **Consulta 2 (Payments):** `percentage_with_payment_events` sería **bajo (< 50%)**
- **Consulta 4 (Shipping):** `percentage_with_active_carriers` sería **bajo (< 50%)**
- **Consulta 1 y 3:** Muchas tiendas con `has_payment_event = 0` o `has_active_carrier = 0`

## 🔧 Próximos Pasos Según Resultados

### Si los porcentajes son altos (> 90%)
✅ **Conclusión:** Los modelos funcionan correctamente con freemium
- Los eventos/carriers se registran automáticamente
- No se necesitan cambios en los modelos

### Si los porcentajes son bajos (< 50%)
❌ **Conclusión:** Hay un problema con freemium
- **Opción A:** Ajustar la lógica de los modelos para considerar `plan_group = 'freemium'` como "configurado por defecto"
- **Opción B:** Coordinar con el equipo de producto para que se registren los eventos/carriers automáticamente
- **Opción C:** Crear una lógica híbrida que considere tanto eventos/carriers como el plan freemium

## 📝 Notas

- Las consultas filtran tiendas creadas desde `2024-01-01` (mismo filtro que los modelos)
- Las consultas usan referencias directas a tablas (no dbt refs) para poder ejecutarse independientemente
- Si necesitas ajustar el rango de fechas, modifica la condición `s.created_at >= '2024-01-01'`

## 👤 Contacto

Si tienes dudas sobre los resultados o necesitas ayuda interpretándolos:
- **Jhu Boggio:** jhu.boggio@tiendanube.com

