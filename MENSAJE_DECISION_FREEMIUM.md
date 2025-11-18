# Mensaje: Decisión sobre manejo de Freemium en modelos de onboarding

---

Hola equipo! 👋

Malen nos preguntó sobre cómo se consideran los casos de freemium en los modelos de onboarding (`s__product_marketing__payments__ref` y `s__product_marketing__shipping__ref`), donde por default ya vienen instalados los medios de pago y envío.

## 🔍 Tests Realizados

Ejecutamos consultas de verificación para entender el comportamiento real:

### Consulta 1: Payments en Freemium
- Verificamos si las tiendas freemium tienen eventos `PaymentProviderRegistered` registrados automáticamente en `journal_payment_provider`

### Consulta 2: Resumen de Payments
- Analizamos el porcentaje de tiendas freemium con eventos de payments registrados

### Consulta 3: Shipping en Freemium  
- Verificamos si las tiendas freemium tienen carriers activos creados automáticamente en `mwp_shipping_carriers`

### Consulta 4: Resumen de Shipping
- Analizamos el porcentaje de tiendas freemium con carriers activos registrados

## 📊 Hallazgos

### Payments
- **Total tiendas freemium analizadas:** 2,011,320
- **Tiendas con eventos `PaymentProviderRegistered`:** 0
- **Porcentaje:** 0.00%

**Conclusión:** ❌ **Ninguna tienda freemium tiene eventos de payments registrados automáticamente** al crearse, aunque técnicamente tienen métodos de pago instalados por defecto.

### Shipping
- **Resultados parciales:** Observamos que algunas tiendas freemium SÍ tienen carriers activos creados automáticamente (diferencia de días = 0), pero otras no.
- **Nota:** Necesitamos el resumen completo para tener el porcentaje exacto.

## 🤔 Problema Identificado

Los modelos actuales detectan configuración basándose en:
- **Payments:** Existencia de eventos `PaymentProviderRegistered` en `journal_payment_provider`
- **Shipping:** Existencia de carriers activos en `mwp_shipping_carriers`

**Impacto:** Las tiendas freemium aparecen como "no configuradas" (`config_payment = 0` y/o `config_shipping = 0`) aunque técnicamente ya tienen todo instalado por defecto.

## 💡 Opciones Disponibles

### Opción A: Ajustar lógica de los modelos
**Descripción:** Modificar los modelos para considerar `plan_group = 'freemium'` como "configurado por defecto"

**Implementación:**
- Agregar JOIN con `moltres__mwp_store_info` y `operations_grouping_plans`
- Si `plan_group = 'freemium'` → `config_payment = 1` y `config_shipping = 1` (independientemente de eventos/carriers)
- Agregar columna `plan_group` a los modelos para facilitar filtrado futuro

**Pros:**
- ✅ Refleja la realidad: freemium tiene todo instalado
- ✅ No requiere cambios en el backend
- ✅ Los modelos reflejan el estado real de configuración

**Contras:**
- ⚠️ Lógica más compleja en los modelos
- ⚠️ Dependencia adicional (tabla de planes)

### Opción B: Coordinar con Producto para registrar eventos automáticamente
**Descripción:** Solicitar al equipo de producto que registre eventos/carriers automáticamente al crear tiendas freemium

**Implementación:**
- Backend registra `PaymentProviderRegistered` al crear tienda freemium
- Backend crea carriers activos automáticamente al crear tienda freemium
- Los modelos actuales funcionan sin cambios

**Pros:**
- ✅ Los modelos no necesitan cambios
- ✅ Los eventos reflejan la realidad del sistema
- ✅ Consistencia: todos los planes se comportan igual

**Contras:**
- ⚠️ Requiere cambios en el backend (tiempo de desarrollo)
- ⚠️ Depende de otro equipo
- ⚠️ Puede tomar tiempo implementar

### Opción C: Lógica híbrida
**Descripción:** Combinar ambas: considerar freemium como configurado, pero también detectar eventos/carriers cuando existan

**Implementación:**
- Si `plan_group = 'freemium'` → `config_payment = 1` y `config_shipping = 1`
- Si no es freemium → usar lógica actual (eventos/carriers)
- Si es freemium Y tiene eventos/carriers → usar fechas de eventos/carriers

**Pros:**
- ✅ Cubre ambos casos (automático y manual)
- ✅ Más robusto

**Contras:**
- ⚠️ Lógica más compleja
- ⚠️ Puede ser confuso entender cuándo se aplica cada regla

## 🎯 Recomendación

**Opción A (Ajustar lógica de los modelos)** por las siguientes razones:

1. **Rapidez:** Se puede implementar inmediatamente sin depender de otros equipos
2. **Precisión:** Refleja la realidad: freemium tiene todo instalado por defecto
3. **Consistencia:** Los datos serán correctos desde el inicio
4. **Bajo riesgo:** No afecta el backend ni otros sistemas

**Adicional:** Agregar columna `plan_group` a los modelos facilitará análisis futuros y filtrado directo sin JOINs adicionales.

## ❓ Preguntas para el equipo

1. ¿Cuál opción prefieren? (A, B, C, u otra)
2. ¿Hay alguna consideración de negocio que debamos tener en cuenta?
3. ¿Necesitamos diferenciar entre "configurado automáticamente" vs "configurado manualmente" en los datos?
4. ¿Quieren que agreguemos la columna `plan_group` a los modelos independientemente de la opción elegida?

## 📝 Próximos Pasos

Una vez decidamos la opción:
- Implementaremos los cambios necesarios
- Actualizaremos la documentación
- Ejecutaremos tests de validación
- Actualizaremos los datos históricos si es necesario

---

**Archivos relacionados:**
- Consultas de verificación: `VERIFICACION_FREEMIUM.sql`
- Script de ejecución: `ejecutar_verificacion_freemium.py`
- Respuesta inicial a Malen: `RESPUESTA_MALEN_FREEMIUM.md`

**Contacto:** jhu.boggio@tiendanube.com

