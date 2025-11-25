// 🧹 AGREGAR ESTA FUNCIÓN al nodo que estructura `for_ai_transform`

function cleanEventName(eventName) {
  if (!eventName) return eventName;
  
  // Limpiar sufijos _pw y convertir a formato amigable
  return eventName
    .replace(/_pw$/, '')  // Quitar "_pw" del final
    .replace(/cybermonday-(\d{4})/, 'Cyber Monday $1')  // cybermonday-2025 → Cyber Monday 2025
    .replace(/hotsale-(\d{4})/, 'Hot Sale $1')          // hotsale-2024 → Hot Sale 2024
    .replace(/blackfriday-(\d{4})/, 'Black Friday $1')  // blackfriday-2025 → Black Friday 2025
    .replace(/buenfin-(\d{4})/, 'Buen Fin $1');         // buenfin-2024 → Buen Fin 2024
}

// 🎯 APLICAR EN event_context:
const for_ai_transform = {
  report_type: "special_events_comparison",
  generated_at: new Date().toISOString(),
  event_context: {
    current_event: cleanEventName(coreMetrics?.eventos_comparison?.current_event),
    last_event: cleanEventName(coreMetrics?.eventos_comparison?.last_event),
    current_event_raw: coreMetrics?.eventos_comparison?.current_event,  // Mantener original para debug
    last_event_raw: coreMetrics?.eventos_comparison?.last_event,
    comparison_type: "event_vs_event",
    last_updated: {
      core: lastUpdatedCore?.[0]?.[1],
      sessions: lastUpdatedSessions?.[0]?.[1], 
      products: lastUpdatedProducts?.[0]?.[1]
    }
  },
  // ... resto del objeto
};


