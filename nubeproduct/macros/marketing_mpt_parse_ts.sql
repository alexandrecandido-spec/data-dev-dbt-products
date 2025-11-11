-- creado por sofia.torres@tiendanube.com
-- Macro para parsear fechas de texto
-- macros/marketing_mpt_parse_ts.sql
{% macro marketing_mpt_parse_ts(str_col) -%}
coalesce(
  /* día/mes/año con y sin hora */
  to_timestamp(trim({{ str_col }}), 'd/M/yyyy HH:mm:ss'),
  to_timestamp(trim({{ str_col }}), 'd/M/yyyy'),

  /* mes/día/año con y sin hora (fallback) */
  to_timestamp(trim({{ str_col }}), 'M/d/yyyy HH:mm:ss'),
  to_timestamp(trim({{ str_col }}), 'M/d/yyyy'),

  /* ISO comunes por si aparecen */
  to_timestamp(trim({{ str_col }}), 'yyyy-MM-dd HH:mm:ss'),
  to_timestamp(trim({{ str_col }}), 'yyyy-MM-dd')
)
{%- endmacro %}
