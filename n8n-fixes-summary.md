# 🔧 Soluciones para los 6 problemas identificados

## 1. 🔄 **Control de flujo - Reintentos Databricks**
**Problema:** Si Databricks falla, n8n sigue con datos vacíos  
**Solución:** Nodo de validación antes del AI Agent
```javascript
// Validar que hay datos reales
const hasValidData = (databricksResult && Array.isArray(databricksResult.data) && databricksResult.data.length > 0);
if (!hasValidData) {
  return [{ json: { error: "Databricks empty", retry_needed: true } }];
}
```
**Implementar:** Agregar nodo de validación → Si falla → Wait (5min) → Reintentar

---

## 2. 🚨 **Prevenir invención de datos del AI**
**Problema:** AI inventa eventos y números cuando no hay datos  
**Solución:** Validación de seguridad AL INICIO del prompt del AI Agent
```
ANTES DE GENERAR EL REPORTE:
VERIFICAR que `for_ai_transform` existe y tiene datos reales
SI FALTA CUALQUIER DATO CRÍTICO:
RESPONDER: {"notification_text": "⚠️ Error: Datos incompletos", "blocks": [...]}
NUNCA INVENTES DATOS. NUNCA GENERES NÚMEROS FALSOS.
```

---

## 3. 🧹 **Limpiar nombres de eventos (_pw)**
**Problema:** "cybermonday-2025_pw" se muestra como "cybermonday 2025"  
**Solución:** Función de limpieza en el nodo que estructura `for_ai_transform`
```javascript
function cleanEventName(eventName) {
  return eventName
    .replace(/_pw$/, '')  // Quitar "_pw"
    .replace(/cybermonday-(\d{4})/, 'Cyber Monday $1')
    .replace(/hotsale-(\d{4})/, 'Hot Sale $1');
}
```

---

## 4. 📅 **3 Fechas obligatorias**
**Problema:** Solo muestra 1 fecha (core), faltan sessions y products  
**Solución:** Prompt más estricto con **OBLIGATORIO - 3 FECHAS SEPARADAS**
```
**OBLIGATORIO - 3 FECHAS SEPARADAS:**
• *Core:* event_context.last_updated.core (formato DD/MM/YYYY HH:MM)
• *Sessions:* event_context.last_updated.sessions (formato DD/MM/YYYY HH:MM)  
• *Products:* event_context.last_updated.products (formato DD/MM/YYYY HH:MM)
```

---

## 5. 📐 **Líneas separadoras**
**Problema:** Prefiere formato con separadores visuales  
**Solución:** Agregar dividers en las reglas JSON
```
REGLAS JSON CRÍTICAS:
- **DIVIDERS:** {"type": "divider"} entre secciones principales
```

---

## 6. ⏰ **Validación ventanas de tiempo**
**Problema:** ¿Ambos eventos comparan misma cantidad días/horas?  
**Respuesta:** ✅ **SÍ, la lógica es CORRECTA**

```sql
-- max_day y max_hour se calculan solo del current_event
current_event_limit AS (
  SELECT MAX(special_date_day) AS max_day, MAX(special_date_hour) AS max_hour
  WHERE special_date_name = ec.current_event  -- ✅ Solo evento actual
),
-- MISMO filtro aplicado a ambos eventos  
WHERE (special_date_day < cel.max_day OR 
       (special_date_day = cel.max_day AND special_date_hour <= cel.max_hour))
```

**Confirmado:** Ambos eventos usan EXACTAMENTE la misma ventana de tiempo. La comparación es justa y precisa.

---

## 🎯 **Acciones inmediatas:**
1. Actualizar prompt del AI Agent con las reglas de seguridad y 3 fechas
2. Agregar función `cleanEventName()` al nodo de estructuración  
3. Implementar nodo de validación antes del AI Agent
4. Agregar dividers en las reglas JSON del prompt

¿Empezamos con el prompt actualizado? 🚀


