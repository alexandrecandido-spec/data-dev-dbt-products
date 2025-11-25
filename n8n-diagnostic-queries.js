// n8n Code node (JavaScript) - DIAGNÓSTICO TEMPORAL
// Entender por qué la comparación no es justa

const CFG = {
  CURRENT_EVENT: "cybermonday-2025",
  LAST_EVENT: "cybermonday-2024",
  TABLES: {
    CORE_ACTUAL: "data_products_dev.testing_marketing.special_events_actual",
    CORE_HISTORICO: "data_products_dev.testing_marketing.special_events_historico"
  }
};

const minify = (s) =>
  s.replace(/--.*$/gm, "")
   .replace(/\/\*[\s\S]*?\*\//g, "")
   .replace(/\s+/g, " ")
   .trim();

// 1. DIAGNÓSTICO: ¿Qué ventana temporal estamos usando?
const generateDiagnosticTimeWindow = () => `
WITH 
events_config AS (
  SELECT 
    '${CFG.CURRENT_EVENT}' AS current_event,
    '${CFG.LAST_EVENT}' AS last_event
),
all_data AS (
  SELECT * FROM ${CFG.TABLES.CORE_ACTUAL}
  UNION ALL
  SELECT * FROM ${CFG.TABLES.CORE_HISTORICO}
),
current_event_limit AS (
  SELECT 
    MAX(special_date_day) AS max_day,
    MAX(special_date_hour) AS max_hour,
    COUNT(*) AS total_records,
    MIN(special_date_day) AS min_day,
    MIN(special_date_hour) AS min_hour
  FROM all_data
  CROSS JOIN events_config ec
  WHERE special_date_name = ec.current_event
),
event_ranges AS (
  SELECT 
    special_date_name,
    MIN(special_date_day) AS min_day,
    MAX(special_date_day) AS max_day,
    MIN(special_date_hour) AS min_hour,
    MAX(special_date_hour) AS max_hour,
    COUNT(*) AS total_records,
    SUM(orders) AS total_orders
  FROM all_data
  CROSS JOIN events_config ec
  WHERE special_date_name IN (ec.current_event, ec.last_event)
  GROUP BY special_date_name
)

SELECT 
  'CURRENT EVENT LIMIT' AS diagnostic_type,
  CAST(cel.max_day AS STRING) AS max_day,
  CAST(cel.max_hour AS STRING) AS max_hour,
  CAST(cel.total_records AS STRING) AS total_records,
  NULL AS event_name,
  NULL AS total_orders
FROM current_event_limit cel

UNION ALL

SELECT 
  'EVENT RANGES' AS diagnostic_type,
  CONCAT('Day ', min_day, ' to ', max_day) AS day_range,
  CONCAT('Hour ', min_hour, ' to ', max_hour) AS hour_range,
  CAST(total_records AS STRING) AS total_records,
  event_name,
  CAST(total_orders AS STRING) AS total_orders
FROM event_ranges er
ORDER BY diagnostic_type, event_name`;

// 2. DIAGNÓSTICO: ¿Cómo se ven los datos ANTES y DESPUÉS del filtro?
const generateDiagnosticBeforeAfter = () => `
WITH 
events_config AS (
  SELECT 
    '${CFG.CURRENT_EVENT}' AS current_event,
    '${CFG.LAST_EVENT}' AS last_event
),
all_data AS (
  SELECT * FROM ${CFG.TABLES.CORE_ACTUAL}
  UNION ALL
  SELECT * FROM ${CFG.TABLES.CORE_HISTORICO}
),
current_event_limit AS (
  SELECT 
    MAX(special_date_day) AS max_day,
    MAX(special_date_hour) AS max_hour
  FROM all_data
  CROSS JOIN events_config ec
  WHERE special_date_name = ec.current_event
),
before_filter AS (
  SELECT 
    cd.special_date_name,
    SUM(cd.orders) AS orders_before_filter,
    COUNT(*) AS records_before_filter
  FROM all_data cd
  CROSS JOIN events_config ec
  WHERE cd.special_date_name IN (ec.current_event, ec.last_event)
  GROUP BY cd.special_date_name
),
after_filter AS (
  SELECT 
    cd.special_date_name,
    SUM(cd.orders) AS orders_after_filter,
    COUNT(*) AS records_after_filter
  FROM all_data cd
  CROSS JOIN current_event_limit cel
  CROSS JOIN events_config ec
  WHERE cd.special_date_name IN (ec.current_event, ec.last_event)
    AND (cd.special_date_day < cel.max_day OR 
         (cd.special_date_day = cel.max_day AND cd.special_date_hour < cel.max_hour))
  GROUP BY cd.special_date_name
)

SELECT 
  bf.special_date_name AS event_name,
  bf.orders_before_filter,
  bf.records_before_filter,
  COALESCE(af.orders_after_filter, 0) AS orders_after_filter,
  COALESCE(af.records_after_filter, 0) AS records_after_filter,
  ROUND((COALESCE(af.orders_after_filter, 0) - bf.orders_before_filter) * 100.0 / 
        NULLIF(bf.orders_before_filter, 0), 2) AS pct_change_orders,
  ROUND((COALESCE(af.records_after_filter, 0) - bf.records_before_filter) * 100.0 / 
        NULLIF(bf.records_before_filter, 0), 2) AS pct_change_records
FROM before_filter bf
LEFT JOIN after_filter af ON bf.special_date_name = af.special_date_name
ORDER BY bf.special_date_name`;

// 3. DIAGNÓSTICO: ¿Cuántas horas tiene cada evento?
const generateDiagnosticHourlyBreakdown = () => `
WITH 
events_config AS (
  SELECT 
    '${CFG.CURRENT_EVENT}' AS current_event,
    '${CFG.LAST_EVENT}' AS last_event
),
all_data AS (
  SELECT * FROM ${CFG.TABLES.CORE_ACTUAL}
  UNION ALL
  SELECT * FROM ${CFG.TABLES.CORE_HISTORICO}
),
hourly_breakdown AS (
  SELECT 
    cd.special_date_name,
    cd.special_date_day,
    cd.special_date_hour,
    SUM(cd.orders) AS hourly_orders,
    COUNT(*) AS hourly_records
  FROM all_data cd
  CROSS JOIN events_config ec
  WHERE cd.special_date_name IN (ec.current_event, ec.last_event)
  GROUP BY cd.special_date_name, cd.special_date_day, cd.special_date_hour
)

SELECT 
  special_date_name AS event_name,
  COUNT(*) AS total_hours,
  MIN(special_date_day) AS first_day,
  MAX(special_date_day) AS last_day,
  MIN(special_date_hour) AS first_hour,
  MAX(special_date_hour) AS last_hour,
  SUM(hourly_orders) AS total_orders,
  ROUND(AVG(hourly_orders), 2) AS avg_orders_per_hour
FROM hourly_breakdown
GROUP BY special_date_name
ORDER BY special_date_name`;

const queries = [
  { name: "diagnostic_time_window", generator: generateDiagnosticTimeWindow },
  { name: "diagnostic_before_after", generator: generateDiagnosticBeforeAfter },
  { name: "diagnostic_hourly_breakdown", generator: generateDiagnosticHourlyBreakdown }
];

const items = queries.map(({ name, generator }) => ({
  json: {
    needs_confirmation: false,
    query_name: name,
    sql: minify(generator()),
    diagnostic_purpose: "temporal_comparison_analysis",
    generated_at: new Date().toISOString()
  }
}));

return items;


