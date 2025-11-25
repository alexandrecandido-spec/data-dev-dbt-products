// n8n Code node (JavaScript)
// DATABRICKS SQL EXECUTION con POLLING automático
// Maneja POST inicial + GET polling hasta completion

// =====================================================
// ⚙️ CONFIGURACIÓN
// =====================================================
const CONFIG = {
  // Retry settings
  MAX_POLLING_ATTEMPTS: 15,    // Máximo 15 intentos de polling (más de 5 minutos)
  INITIAL_DELAY: 3000,         // 3 segundos inicial
  MAX_DELAY: 30000,            // Máximo 30 segundos
  BACKOFF_FACTOR: 1.3,         // Incremento gradual
  
  // Estados de Databricks
  SUCCESS_STATES: ['SUCCEEDED', 'FINISHED', 'COMPLETED'],
  PENDING_STATES: ['PENDING', 'RUNNING', 'EXECUTING', 'QUEUED'],
  FAILURE_STATES: ['FAILED', 'CANCELLED', 'ERROR', 'TIMEOUT', 'INTERNAL_ERROR'],
  
  // Endpoints (ajustar según tu configuración)
  DATABRICKS_BASE_URL: 'https://tu-workspace.cloud.databricks.com',
  SQL_ENDPOINT: '/api/2.0/sql/statements',
  
  // Headers
  HEADERS: {
    'Authorization': `Bearer ${$env.DATABRICKS_TOKEN}`,
    'Content-Type': 'application/json'
  }
};

// =====================================================
// 🛠️ UTILITY FUNCTIONS
// =====================================================

const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

const calculateDelay = (attempt) => {
  const delay = CONFIG.INITIAL_DELAY * Math.pow(CONFIG.BACKOFF_FACTOR, attempt - 1);
  return Math.min(delay, CONFIG.MAX_DELAY);
};

const getState = (response) => {
  // Extraer estado de diferentes posibles estructuras de respuesta
  return response?.state || 
         response?.status || 
         response?.result_state || 
         response?.execution_status ||
         response?.data?.state ||
         response?.data?.status ||
         'UNKNOWN';
};

const shouldContinuePolling = (state) => {
  return CONFIG.PENDING_STATES.includes(state.toUpperCase());
};

const isSuccess = (state) => {
  return CONFIG.SUCCESS_STATES.includes(state.toUpperCase());
};

const isFailure = (state) => {
  return CONFIG.FAILURE_STATES.includes(state.toUpperCase());
};

// =====================================================
// 🎯 MAIN DATABRICKS EXECUTION FUNCTION
// =====================================================

async function executeDatabricksQuery(sqlQuery, warehouseId) {
  let statementId = null;
  let attempt = 0;
  
  try {
    // ===================================
    // 📤 PASO 1: POST - Iniciar ejecución
    // ===================================
    console.log('🚀 Enviando query a Databricks...');
    console.log(`📝 Query: ${sqlQuery.substring(0, 100)}...`);
    
    const postPayload = {
      statement: sqlQuery,
      warehouse_id: warehouseId,
      wait_timeout: '10s',  // Esperar máximo 10s antes de retornar PENDING
      disposition: 'EXTERNAL_LINKS'
    };
    
    const initialResponse = await $http.post(
      `${CONFIG.DATABRICKS_BASE_URL}${CONFIG.SQL_ENDPOINT}`,
      postPayload,
      { headers: CONFIG.HEADERS }
    );
    
    statementId = initialResponse.data.statement_id;
    let currentState = getState(initialResponse.data);
    
    console.log(`📋 Statement ID: ${statementId}`);
    console.log(`📊 Estado inicial: ${currentState}`);
    
    // Si ya está completo, retornar inmediatamente
    if (isSuccess(currentState)) {
      console.log('✅ Query completada inmediatamente!');
      return {
        success: true,
        statement_id: statementId,
        final_state: currentState,
        attempts: 1,
        data: initialResponse.data,
        execution_time_ms: 0
      };
    }
    
    // Si falló inmediatamente
    if (isFailure(currentState)) {
      console.log(`❌ Query falló inmediatamente: ${currentState}`);
      return {
        success: false,
        statement_id: statementId,
        final_state: currentState,
        attempts: 1,
        error: `Query falló: ${currentState}`,
        data: initialResponse.data
      };
    }
    
    // ===================================
    // 🔄 PASO 2: POLLING - Verificar estado
    // ===================================
    
    if (!shouldContinuePolling(currentState)) {
      // Estado desconocido pero no PENDING - asumir éxito
      return {
        success: true,
        statement_id: statementId,
        final_state: currentState,
        attempts: 1,
        data: initialResponse.data,
        warning: `Estado desconocido: ${currentState}`
      };
    }
    
    // Iniciar polling
    console.log('⏳ Iniciando polling...');
    const startTime = Date.now();
    
    while (attempt < CONFIG.MAX_POLLING_ATTEMPTS && shouldContinuePolling(currentState)) {
      attempt++;
      
      // Esperar antes del siguiente intento
      const delay = calculateDelay(attempt);
      console.log(`💤 Esperando ${delay}ms... (Intento ${attempt}/${CONFIG.MAX_POLLING_ATTEMPTS})`);
      await sleep(delay);
      
      // GET para verificar estado
      try {
        console.log(`📡 Polling intento ${attempt}...`);
        
        const pollResponse = await $http.get(
          `${CONFIG.DATABRICKS_BASE_URL}${CONFIG.SQL_ENDPOINT}/${statementId}`,
          { headers: CONFIG.HEADERS }
        );
        
        currentState = getState(pollResponse.data);
        console.log(`📊 Estado actual: ${currentState}`);
        
        // Verificar si completó
        if (isSuccess(currentState)) {
          const executionTime = Date.now() - startTime;
          console.log(`✅ ¡Query completada exitosamente en ${attempt} intentos! (${executionTime}ms)`);
          
          return {
            success: true,
            statement_id: statementId,
            final_state: currentState,
            attempts: attempt + 1,
            execution_time_ms: executionTime,
            data: pollResponse.data
          };
        }
        
        // Verificar si falló
        if (isFailure(currentState)) {
          const executionTime = Date.now() - startTime;
          console.log(`❌ Query falló: ${currentState}`);
          
          return {
            success: false,
            statement_id: statementId,
            final_state: currentState,
            attempts: attempt + 1,
            execution_time_ms: executionTime,
            error: `Query falló con estado: ${currentState}`,
            data: pollResponse.data
          };
        }
        
        // Continuar polling si sigue PENDING
        
      } catch (pollError) {
        console.log(`⚠️ Error en polling intento ${attempt}: ${pollError.message}`);
        
        // Si es el último intento, fallar
        if (attempt >= CONFIG.MAX_POLLING_ATTEMPTS) {
          throw pollError;
        }
        // Sino, continuar con el siguiente intento
      }
    }
    
    // Si salimos del loop, se agotaron los intentos
    const executionTime = Date.now() - startTime;
    console.log(`🔴 Timeout: Se agotaron ${CONFIG.MAX_POLLING_ATTEMPTS} intentos de polling`);
    
    return {
      success: false,
      statement_id: statementId,
      final_state: currentState,
      attempts: attempt + 1,
      execution_time_ms: executionTime,
      error: `Timeout: Query sigue en estado ${currentState} después de ${attempt} intentos`,
      timeout: true
    };
    
  } catch (error) {
    console.log(`💥 Error crítico: ${error.message}`);
    
    return {
      success: false,
      statement_id: statementId,
      final_state: 'ERROR',
      attempts: attempt + 1,
      error: error.message,
      critical_error: true
    };
  }
}

// =====================================================
// 🚀 EJECUCIÓN PRINCIPAL
// =====================================================

// Obtener parámetros del nodo anterior o variables de entorno
const sqlQuery = $input.all()[0].json.sql || $env.SQL_QUERY;
const warehouseId = $input.all()[0].json.warehouse_id || $env.DATABRICKS_WAREHOUSE_ID;

if (!sqlQuery) {
  throw new Error('❌ No se proporcionó SQL query');
}

if (!warehouseId) {
  throw new Error('❌ No se proporcionó warehouse_id');
}

console.log('🎯 Iniciando ejecución de Databricks con polling automático...');
console.log(`🏢 Warehouse ID: ${warehouseId}`);

// Ejecutar query con retry automático
const result = await executeDatabricksQuery(sqlQuery, warehouseId);

// Log resultado final
console.log('📋 RESULTADO FINAL:');
console.log(`   ✓ Éxito: ${result.success}`);
console.log(`   ✓ Estado: ${result.final_state}`);
console.log(`   ✓ Intentos: ${result.attempts}`);
if (result.execution_time_ms) {
  console.log(`   ✓ Tiempo: ${result.execution_time_ms}ms`);
}

// Retornar resultado para el siguiente nodo
return [result];


