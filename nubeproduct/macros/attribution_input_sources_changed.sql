{% macro input_changed(input_name) %}
(
  POSITION('{{ input_name }}' IN COALESCE(e.input_sources, '')) > 0
  AND POSITION('{{ input_name }}' IN COALESCE(main_source.input_sources, '')) = 0
)
OR (
  POSITION('{{ input_name }}' IN COALESCE(e.input_sources, '')) = 0
  AND POSITION('{{ input_name }}' IN COALESCE(main_source.input_sources, '')) > 0
)
{% endmacro %}