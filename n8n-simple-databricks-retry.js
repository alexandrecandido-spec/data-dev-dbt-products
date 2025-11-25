// n8n Code node (JavaScript) - SIMPLE RETRY LOGIC
// Para usar DESPUÉS de tu nodo Databricks existente
// Detecta estado PENDING y hace polling automático

// =====================================================
// ⚙️ CONFIGURACIÓN SIMPLE
// =====================================================
const RETRY_CONFIG = {
  MAX_ATTEMPTS: 8,           // Máximo 8 intentos (más de 5 como pediste)
  DELAY_SECONDS: 4,          // 4 segundos entre intentos
  MAX_DELAY_SECONDS: 25,     // Máximo 25 segundos
  
  // Estados que requieren retry
  PENDING_STATES: ['PENDING', 'RUNNING', 'EXECUTING', 'QUEUED'],
  SUCCESS_STATES: ['SUCCEEDED', 'FINISHED', 'COMPLETED'],
  FAILURE_STATES: ['FAILED', 'CANCELLED', 'ERROR', 'TIMEOUT']
};

// =====================================================
// 🔄 FUNCIÓN DE RETRY SIMPLE
// =====================================================

async function retryIfPending() {
  // Obtener datos del nodo anterior (tu llamada inicial a Databricks)
  const inputData = $input.all()[0].json;
  
  console.log('🔍 Verificando estado de Databricks...');
  
  // Extraer información necesaria
  const statementId = inputData.statement_id || inputData.id;
  const currentState = inputData.state || inputData.status || inputData.result_state;
  
  console.log(`📊 Estado inicial: ${currentState}`);
  console.log(`🆔 Statement ID: ${statementId}`);
  
  // Si no hay statement_id, no podemos hacer polling
  if (!statementId) {
    console.log('⚠️ No se encontró statement_id, retornando datos originales');
    return inputData;
  }
  
  // Si ya está completo, retornar inmediatamente
  if (RETRY_CONFIG.SUCCESS_STATES.includes(currentState?.toUpperCase())) {
    console.log('✅ Query ya completada!');
    return inputData;
  }
  
  // Si falló, retornar inmediatamente
  if (RETRY_CONFIG.FAILURE_STATES.includes(currentState?.toUpperCase())) {
    console.log(`❌ Query falló: ${currentState}`);
    return {
      ...inputData,
      polling_result: 'FAILED',
      error: `Query falló con estado: ${currentState}`
    };
  }
  
  // Si no está PENDING, asumir éxito
  if (!RETRY_CONFIG.PENDING_STATES.includes(currentState?.toUpperCase())) {
    console.log(`🤔 Estado desconocido (${currentState}), asumiendo éxito`);
    return inputData;
  }
  
  // ===================================
  // 🔄 INICIAR POLLING
  // ===================================
  
  console.log('⏳ Estado PENDING detectado, iniciando polling...');
  
  for (let attempt = 1; attempt <= RETRY_CONFIG.MAX_ATTEMPTS; attempt++) {
    
    // Calcular delay (incremento gradual)
    const delay = Math.min(
      RETRY_CONFIG.DELAY_SECONDS * attempt, 
      RETRY_CONFIG.MAX_DELAY_SECONDS
    ) * 1000;
    
    console.log(`💤 Esperando ${delay/1000}s... (Intento ${attempt}/${RETRY_CONFIG.MAX_ATTEMPTS})`);
    await new Promise(resolve => setTimeout(resolve, delay));
    
    try {
      console.log(`📡 Verificando estado - Intento ${attempt}...`);
      
      // ===================================
      // 🎯 HACER GET REQUEST A DATABRICKS
      // ===================================
      
      // Construir URL (ajusta según tu endpoint)
      const checkUrl = `https://tu-workspace.cloud.databricks.com/api/2.0/sql/statements/${statementId}`;
      
      const response = await $http.get(checkUrl, {
        headers: {
          'Authorization': `Bearer ${$env.DATABRICKS_TOKEN}`,
          'Content-Type': 'application/json'
        }
      });
      
      const newState = response.data.state || response.data.status || response.data.result_state;
      console.log(`📊 Nuevo estado: ${newState}`);
      
      // ===================================
      // 🎯 EVALUAR RESULTADO
      // ===================================
      
      // Éxito
      if (RETRY_CONFIG.SUCCESS_STATES.includes(newState?.toUpperCase())) {
        console.log(`✅ ¡Query completada en intento ${attempt}!`);
        return {
          ...response.data,
          polling_result: 'SUCCESS',
          polling_attempts: attempt,
          original_data: inputData
        };
      }
      
      // Fallo
      if (RETRY_CONFIG.FAILURE_STATES.includes(newState?.toUpperCase())) {
        console.log(`❌ Query falló en intento ${attempt}: ${newState}`);
        return {
          ...response.data,
          polling_result: 'FAILED',
          polling_attempts: attempt,
          error: `Query falló: ${newState}`,
          original_data: inputData
        };
      }
      
      // Sigue PENDING - continuar
      if (RETRY_CONFIG.PENDING_STATES.includes(newState?.toUpperCase())) {
        console.log(`⏳ Sigue ${newState}, continuando polling...`);
        // Continuar con el siguiente intento
        continue;
      }
      
      // Estado desconocido - asumir éxito
      console.log(`🤔 Estado desconocido: ${newState}, asumiendo éxito`);
      return {
        ...response.data,
        polling_result: 'SUCCESS_UNKNOWN_STATE',
        polling_attempts: attempt,
        warning: `Estado desconocido: ${newState}`,
        original_data: inputData
      };
      
    } catch (error) {
      console.log(`⚠️ Error en intento ${attempt}: ${error.message}`);
      
      // Si es el último intento, fallar
      if (attempt >= RETRY_CONFIG.MAX_ATTEMPTS) {
        return {
          ...inputData,
          polling_result: 'ERROR',
          polling_attempts: attempt,
          error: `Error después de ${attempt} intentos: ${error.message}`
        };
      }
      
      // Sino, continuar con el siguiente intento
    }
  }
  
  // Si llegamos aquí, se agotaron los intentos
  console.log(`🔴 Timeout: Se agotaron ${RETRY_CONFIG.MAX_ATTEMPTS} intentos`);
  return {
    ...inputData,
    polling_result: 'TIMEOUT',
    polling_attempts: RETRY_CONFIG.MAX_ATTEMPTS,
    error: `Timeout: Query sigue PENDING después de ${RETRY_CONFIG.MAX_ATTEMPTS} intentos`
  };
}

// =====================================================
// 🚀 EJECUTAR Y RETORNAR
// =====================================================

console.log('🎯 Iniciando retry logic para Databricks...');

const result = await retryIfPending();

// Log resultado
console.log('📋 RESULTADO:');
console.log(`   Estado: ${result.state || result.status || 'N/A'}`);
console.log(`   Polling: ${result.polling_result || 'NO_POLLING_NEEDED'}`);
if (result.polling_attempts) {
  console.log(`   Intentos: ${result.polling_attempts}`);
}

return result;


