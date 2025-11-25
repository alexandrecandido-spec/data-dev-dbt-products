# 🎯 FIX PARA SHARES DE PERFORMANCE

## 🔍 PROBLEMA IDENTIFICADO

Los **shares (porcentajes) de la sección Performance** no coincidían con los tableros, aunque los valores absolutos sí coincidían.

**Secciones afectadas en Performance:**
- ✅ Installments (shares incorrectos)
- ✅ Payment Gateway (shares incorrectos)
- ✅ Shipping (shares incorrectos)  
- ✅ Provinces (shares incorrectos)
- ✅ Traffic (funcionaba bien)
- ✅ Categories (funcionaba bien)

## 🎯 CAUSA RAÍZ

**Shares Analysis** estaba usando **tiempo relativo**, pero debería usar **lógica antigua** como las otras queries de Performance que funcionaban correctamente.

### ❌ ANTES (tiempo relativo - shares incorrectos):
```sql
WITH ${getRelativeTimeLogic("CORE")},
core_data AS (
  SELECT wr.* FROM with_rel wr 
  WHERE wr.rel_hour <= cel.rel_hour_limit  -- Tiempo relativo
)
```

### ✅ DESPUÉS (lógica antigua - shares correctos):
```sql  
WITH ${getOldTimeLogic("CORE")},
core_data AS (
  SELECT cd.* FROM all_data cd
  WHERE (cd.special_date_day < cel.max_day OR 
         (cd.special_date_day = cel.max_day AND cd.special_date_hour <= cel.max_hour))  -- Lógica antigua
)
```

## 🔧 DISTRIBUCIÓN FINAL DE LÓGICAS

### 📊 **TIEMPO RELATIVO** (comparaciones justas entre eventos):
- ✅ General Metrics
- ✅ Active Stores  
- ✅ Business Unit
- ✅ Store Age
- ✅ Consumers
- ✅ Promotions
- ✅ Temporal
- ✅ Last Updated

### ⚡ **LÓGICA ANTIGUA** (Performance que funcionaba):
- ✅ **Shares Analysis** → Genera datos para Installments, Payment Gateway, Shipping, Provinces
- ✅ **Traffic** → Genera datos para Traffic
- ✅ **Products** → Genera datos para Categories

## 🎯 RESULTADO

**Ahora TODOS los shares de Performance deberían coincidir exactamente con los tableros** mientras se mantienen las comparaciones justas para las métricas principales.

## 📂 ARCHIVO CORREGIDO

`n8n-query-generator-PERFORMANCE-FIXED.js`

**Temporal fix**: `HYBRID_RELATIVE_TIME_FOR_MAIN_METRICS_OLD_LOGIC_FOR_ALL_PERFORMANCE`


