// n8n Code node (JavaScript) - REEMPLAZO para GET Databricks con RETRY
// Usa el statement_id del POST anterior y hace polling hasta completar

// =====================================================
// ⚙️ CONFIGURACIÓN
// =====================================================
const RETRY_CONFIG = {
  MAX_ATTEMPTS: 8,           // Máximo 8 intentos
  DELAY_SECONDS: 4,          // 4 segundos inicial
  MAX_DELAY_SECONDS: 25,     // Máximo 25 segundos
  
  // Estados de Databricks
  PENDING_STATES: ['PENDING', 'RUNNING', 'EXECUTING', 'QUEUED'],
  SUCCESS_STATES: ['SUCCEEDED', 'FINISHED', 'COMPLETED'],
  FAILURE_STATES: ['FAILED', 'CANCELLED', 'ERROR', 'TIMEOUT']
};

// =====================================================
// 🔄 FUNCIÓN PRINCIPAL - GET CON RETRY
// =====================================================

async function getDatabricksWithRetry() {
  // Obtener datos del POST anterior
  const postData = $input.all()[0].json;
  
  console.log('🔍 Iniciando GET Databricks con retry...');
  
  // Extraer statement_id del POST
  const statementId = postData.statement_id || postData.id;
  
  if (!statementId) {
    throw new Error('❌ No se encontró statement_id en la respuesta del POST');
  }
  
  console.log(`🆔 Statement ID: ${statementId}`);
  console.log(`📊 Estado inicial del POST: ${postData.state || postData.status || 'N/A'}`);
  
  // ===================================
  // 🎯 CONFIGURAR URL Y HEADERS
  // ===================================
  
  // 🔧 CAMBIAR ESTA URL POR LA TUYA:
  const baseUrl = 'https://TU-WORKSPACE.cloud.databricks.com';
  const checkUrl = `${baseUrl}/api/2.0/sql/statements/${statementId}`;
  
  const headers = {
    'Authorization': `Bearer ${$env.DATABRICKS_TOKEN}`,
    'Content-Type': 'application/json'
  };
  
  // ===================================
  // 🔄 HACER PRIMER GET
  // ===================================
  
  console.log('📡 Haciendo primer GET...');
  
  try {
    const response = await $http.get(checkUrl, { headers });
    let currentState = response.data.state || response.data.status || response.data.result_state;
    
    console.log(`📊 Estado actual: ${currentState}`);
    
    // Si ya está completo, retornar inmediatamente
    if (RETRY_CONFIG.SUCCESS_STATES.includes(currentState?.toUpperCase())) {
      console.log('✅ Query ya completada en primer intento!');
      return {
        ...response.data,
        retry_attempts: 1,
        retry_result: 'SUCCESS_IMMEDIATE'
      };
    }
    
    // Si falló, retornar inmediatamente
    if (RETRY_CONFIG.FAILURE_STATES.includes(currentState?.toUpperCase())) {
      console.log(`❌ Query falló: ${currentState}`);
      return {
        ...response.data,
        retry_attempts: 1,
        retry_result: 'FAILED',
        error: `Query falló con estado: ${currentState}`
      };
    }
    
    // Si no está PENDING, asumir éxito
    if (!RETRY_CONFIG.PENDING_STATES.includes(currentState?.toUpperCase())) {
      console.log(`🤔 Estado desconocido (${currentState}), asumiendo éxito`);
      return {
        ...response.data,
        retry_attempts: 1,
        retry_result: 'SUCCESS_UNKNOWN_STATE',
        warning: `Estado desconocido: ${currentState}`
      };
    }
    
    // ===================================
    // 🔄 ESTÁ PENDING - INICIAR POLLING
    // ===================================
    
    console.log('⏳ Estado PENDING, iniciando polling...');
    
    for (let attempt = 2; attempt <= RETRY_CONFIG.MAX_ATTEMPTS; attempt++) {
      
      // Calcular delay (incremento gradual)
      const delay = Math.min(
        RETRY_CONFIG.DELAY_SECONDS * (attempt - 1), 
        RETRY_CONFIG.MAX_DELAY_SECONDS
      ) * 1000;
      
      console.log(`💤 Esperando ${delay/1000}s... (Intento ${attempt}/${RETRY_CONFIG.MAX_ATTEMPTS})`);
      await new Promise(resolve => setTimeout(resolve, delay));
      
      try {
        console.log(`📡 GET intento ${attempt}...`);
        
        const retryResponse = await $http.get(checkUrl, { headers });
        const newState = retryResponse.data.state || retryResponse.data.status || retryResponse.data.result_state;
        
        console.log(`📊 Nuevo estado: ${newState}`);
        
        // ===================================
        // 🎯 EVALUAR RESULTADO
        // ===================================
        
        // Éxito
        if (RETRY_CONFIG.SUCCESS_STATES.includes(newState?.toUpperCase())) {
          console.log(`✅ ¡Query completada en intento ${attempt}!`);
          return {
            ...retryResponse.data,
            retry_attempts: attempt,
            retry_result: 'SUCCESS_AFTER_RETRY'
          };
        }
        
        // Fallo
        if (RETRY_CONFIG.FAILURE_STATES.includes(newState?.toUpperCase())) {
          console.log(`❌ Query falló en intento ${attempt}: ${newState}`);
          return {
            ...retryResponse.data,
            retry_attempts: attempt,
            retry_result: 'FAILED_AFTER_RETRY',
            error: `Query falló: ${newState}`
          };
        }
        
        // Sigue PENDING - continuar
        if (RETRY_CONFIG.PENDING_STATES.includes(newState?.toUpperCase())) {
          console.log(`⏳ Sigue ${newState}, continuando polling...`);
          currentState = newState;
          continue;
        }
        
        // Estado desconocido - asumir éxito
        console.log(`🤔 Estado desconocido: ${newState}, asumiendo éxito`);
        return {
          ...retryResponse.data,
          retry_attempts: attempt,
          retry_result: 'SUCCESS_UNKNOWN_STATE',
          warning: `Estado desconocido: ${newState}`
        };
        
      } catch (error) {
        console.log(`⚠️ Error en intento ${attempt}: ${error.message}`);
        
        // Si es el último intento, fallar
        if (attempt >= RETRY_CONFIG.MAX_ATTEMPTS) {
          throw error;
        }
        
        // Sino, continuar con el siguiente intento
      }
    }
    
    // Si llegamos aquí, se agotaron los intentos
    console.log(`🔴 Timeout: Se agotaron ${RETRY_CONFIG.MAX_ATTEMPTS} intentos`);
    return {
      state: currentState,
      retry_attempts: RETRY_CONFIG.MAX_ATTEMPTS,
      retry_result: 'TIMEOUT',
      error: `Timeout: Query sigue ${currentState} después de ${RETRY_CONFIG.MAX_ATTEMPTS} intentos`
    };
    
  } catch (error) {
    console.log(`💥 Error crítico: ${error.message}`);
    throw new Error(`Error en GET Databricks: ${error.message}`);
  }
}

// =====================================================
// 🚀 EJECUTAR Y RETORNAR
// =====================================================

console.log('🎯 Reemplazando GET Databricks con retry automático...');

const result = await getDatabricksWithRetry();

// Log resultado
console.log('📋 RESULTADO:');
console.log(`   Estado final: ${result.state || result.status || 'N/A'}`);
console.log(`   Resultado retry: ${result.retry_result || 'N/A'}`);
console.log(`   Intentos: ${result.retry_attempts || 1}`);

return result;


