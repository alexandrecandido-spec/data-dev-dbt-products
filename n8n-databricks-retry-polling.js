// n8n Code node (JavaScript)
// RETRY LOGIC WITH POLLING para Databricks queries
// Maneja estados PENDING, RUNNING, etc. con reintentos automáticos

// =====================================================
// ⚙️ CONFIGURACIÓN DEL RETRY
// =====================================================
const RETRY_CONFIG = {
  MAX_ATTEMPTS: 10,        // Máximo 10 intentos (más que 5 como pediste)
  INITIAL_DELAY: 2000,     // Empezar con 2 segundos
  MAX_DELAY: 30000,        // Máximo 30 segundos entre intentos
  BACKOFF_FACTOR: 1.5,     // Incremento exponencial del delay
  SUCCESS_STATES: ['SUCCEEDED', 'FINISHED', 'COMPLETED'],
  PENDING_STATES: ['PENDING', 'RUNNING', 'EXECUTING', 'QUEUED'],
  FAILURE_STATES: ['FAILED', 'CANCELLED', 'ERROR', 'TIMEOUT']
};

// =====================================================
// 🛠️ UTILITY FUNCTIONS
// =====================================================

// Sleep function
const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

// Calculate delay with exponential backoff
const calculateDelay = (attempt) => {
  const delay = RETRY_CONFIG.INITIAL_DELAY * Math.pow(RETRY_CONFIG.BACKOFF_FACTOR, attempt - 1);
  return Math.min(delay, RETRY_CONFIG.MAX_DELAY);
};

// Check if state requires retry
const shouldRetry = (state) => {
  if (!state) return true; // Si no hay estado, retry
  return RETRY_CONFIG.PENDING_STATES.includes(state.toUpperCase());
};

// Check if state is successful
const isSuccess = (state) => {
  if (!state) return false;
  return RETRY_CONFIG.SUCCESS_STATES.includes(state.toUpperCase());
};

// Check if state is failure
const isFailure = (state) => {
  if (!state) return false;
  return RETRY_CONFIG.FAILURE_STATES.includes(state.toUpperCase());
};

// =====================================================
// 🔄 MAIN RETRY LOGIC
// =====================================================

async function executeWithRetry() {
  let attempt = 1;
  let lastResponse = null;
  let lastError = null;

  console.log(`🚀 Iniciando ejecución con retry (máximo ${RETRY_CONFIG.MAX_ATTEMPTS} intentos)`);

  while (attempt <= RETRY_CONFIG.MAX_ATTEMPTS) {
    try {
      console.log(`📡 Intento ${attempt}/${RETRY_CONFIG.MAX_ATTEMPTS}...`);

      // ===================================
      // 🎯 AQUÍ VA TU LÓGICA DE DATABRICKS
      // ===================================
      
      // Ejemplo 1: Si ya tienes la respuesta inicial y solo necesitas polling
      // Reemplaza esta parte con tu llamada real a Databricks
      const response = await $http.get('TU_DATABRICKS_ENDPOINT_AQUÍ', {
        headers: {
          'Authorization': 'Bearer ' + $env.DATABRICKS_TOKEN,
          'Content-Type': 'application/json'
        }
      });

      // Extraer el estado de la respuesta (ajusta según tu estructura)
      const state = response.data?.state || response.data?.status || response.data?.result_state;
      
      console.log(`📊 Estado actual: ${state}`);
      
      // ===================================
      // 🎯 LÓGICA DE DECISIÓN
      // ===================================
      
      if (isSuccess(state)) {
        console.log(`✅ ¡Éxito en intento ${attempt}! Estado: ${state}`);
        return {
          success: true,
          attempt: attempt,
          final_state: state,
          data: response.data,
          message: `Completado exitosamente en intento ${attempt}`
        };
      }
      
      if (isFailure(state)) {
        console.log(`❌ Fallo definitivo en intento ${attempt}. Estado: ${state}`);
        return {
          success: false,
          attempt: attempt,
          final_state: state,
          data: response.data,
          error: `Query falló con estado: ${state}`
        };
      }
      
      if (shouldRetry(state)) {
        console.log(`⏳ Estado ${state} requiere espera. Continuando...`);
        lastResponse = response.data;
        
        // Si no es el último intento, esperar
        if (attempt < RETRY_CONFIG.MAX_ATTEMPTS) {
          const delay = calculateDelay(attempt);
          console.log(`💤 Esperando ${delay}ms antes del siguiente intento...`);
          await sleep(delay);
        }
      } else {
        // Estado desconocido - tratar como éxito
        console.log(`🤔 Estado desconocido: ${state}. Retornando como éxito.`);
        return {
          success: true,
          attempt: attempt,
          final_state: state,
          data: response.data,
          message: `Completado con estado desconocido: ${state}`
        };
      }

    } catch (error) {
      console.log(`⚠️ Error en intento ${attempt}: ${error.message}`);
      lastError = error;
      
      // Si es el último intento, fallar
      if (attempt >= RETRY_CONFIG.MAX_ATTEMPTS) {
        break;
      }
      
      // Esperar antes del siguiente intento
      const delay = calculateDelay(attempt);
      console.log(`💤 Esperando ${delay}ms tras error antes del siguiente intento...`);
      await sleep(delay);
    }

    attempt++;
  }

  // Si llegamos aquí, se agotaron los intentos
  console.log(`🔴 Se agotaron los ${RETRY_CONFIG.MAX_ATTEMPTS} intentos`);
  
  return {
    success: false,
    attempt: RETRY_CONFIG.MAX_ATTEMPTS,
    final_state: 'MAX_RETRIES_EXCEEDED',
    data: lastResponse,
    error: lastError ? lastError.message : 'Se agotaron los intentos sin respuesta exitosa'
  };
}

// =====================================================
// 🚀 EJECUTAR Y RETORNAR
// =====================================================

// Ejecutar la lógica de retry
const result = await executeWithRetry();

// Log del resultado final
console.log('📋 RESULTADO FINAL:', JSON.stringify(result, null, 2));

// Retornar el resultado para el siguiente nodo
return result;


