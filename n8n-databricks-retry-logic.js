// 🔄 NODO DE VALIDACIÓN Y REINTENTO (poner ANTES del nodo que estructura data para AI)

const databricksResult = $input.first().json;

// ✅ VALIDAR que Databricks devolvió datos reales
const hasValidData = (
  databricksResult && 
  Array.isArray(databricksResult.data) && 
  databricksResult.data.length > 0 &&
  databricksResult.data[0].length > 0  // Al menos una fila con datos
);

if (!hasValidData) {
  // 🚨 FALLÓ - Reintentar (enviar a "Wait" node con 5min delay)
  return [{
    json: {
      error: "Databricks returned empty or invalid data",
      retry_needed: true,
      timestamp: new Date().toISOString(),
      raw_result: databricksResult
    }
  }];
}

// ✅ ÉXITO - Continuar al siguiente nodo
return [{
  json: {
    ...databricksResult,
    validation_passed: true,
    timestamp: new Date().toISOString()
  }
}];


