{% macro get_nonacquisition_terms_detection(search_query_field) %}
CASE
  -- Términos de Login/Acceso
  WHEN CONTAINS(LOWER({{ search_query_field }}), 'login') THEN 'login'
  WHEN CONTAINS(LOWER({{ search_query_field }}), 'logn') THEN 'logn'
  WHEN CONTAINS(LOWER({{ search_query_field }}), 'entrar') THEN 'entrar'
  WHEN CONTAINS(LOWER({{ search_query_field }}), 'acessar') THEN 'acessar'
  WHEN CONTAINS(LOWER({{ search_query_field }}), 'ingresar') THEN 'ingresar'
  WHEN CONTAINS(LOWER({{ search_query_field }}), 'ingreso') THEN 'ingreso'
  WHEN CONTAINS(LOWER({{ search_query_field }}), 'iniciar') THEN 'iniciar'
  WHEN CONTAINS(LOWER({{ search_query_field }}), 'inicio') THEN 'inicio'
  WHEN CONTAINS(LOWER({{ search_query_field }}), 'accesar') THEN 'accesar'
  WHEN CONTAINS(LOWER({{ search_query_field }}), 'accessar') THEN 'accessar'
  
  -- Términos específicos de plataforma
  WHEN CONTAINS(LOWER({{ search_query_field }}), 'minha') THEN 'minha'
  WHEN CONTAINS(LOWER({{ search_query_field }}), 'mitiendanube') THEN 'mitiendanube'
  WHEN CONTAINS(LOWER({{ search_query_field }}), 'mi tiendanube') THEN 'mi tiendanube'
  WHEN CONTAINS(LOWER({{ search_query_field }}), 'mi tienda nube') THEN 'mi tienda nube'
  
  -- Términos de Soporte/Panel
  WHEN CONTAINS(LOWER({{ search_query_field }}), 'suporte') THEN 'suporte'
  WHEN CONTAINS(LOWER({{ search_query_field }}), 'soporte') THEN 'soporte'
  WHEN CONTAINS(LOWER({{ search_query_field }}), 'support') THEN 'support'
  WHEN CONTAINS(LOWER({{ search_query_field }}), 'painel') THEN 'painel'
  WHEN CONTAINS(LOWER({{ search_query_field }}), 'panel') THEN 'panel'
  WHEN CONTAINS(LOWER({{ search_query_field }}), 'administrador') THEN 'administrador'
  WHEN CONTAINS(LOWER({{ search_query_field }}), 'admin') THEN 'admin'
  
  -- Términos técnicos/configuración
  WHEN CONTAINS(LOWER({{ search_query_field }}), 'dominio') THEN 'dominio'
  WHEN CONTAINS(LOWER({{ search_query_field }}), 'templates') THEN 'templates'
  WHEN CONTAINS(LOWER({{ search_query_field }}), 'plantillas') THEN 'plantillas'
  WHEN CONTAINS(LOWER({{ search_query_field }}), 'api') THEN 'api'
  
  ELSE CAST(NULL AS STRING)
END
{% endmacro %}
