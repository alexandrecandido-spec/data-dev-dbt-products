{% macro column_exists(relation, column_name) %}
  {{ return(adapter.get_columns_in_relation(relation) | selectattr("name", "equalto", column_name | lower) | list | length > 0) }}
{% endmacro %}
