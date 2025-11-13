{% macro get_existing_data_where(relation, columns, where_sql=None, on_missing='empty', single_line=True) %}
  {% set rel = relation %}
  {% set rel_is_string = rel is string %}

  {% if not rel_is_string and rel is not none %}
    {% set exists = adapter.get_relation(
      database=rel.database or target.database,
      schema=rel.schema or target.schema,
      identifier=rel.identifier
    ) %}
  {% else %}
    {% set exists = true %}
  {% endif %}

  {%- set sql -%}
    {%- if not exists and on_missing == 'empty' -%}
      select
      {%- for c in columns -%}
        null as {{ c }}{{ ", " if not loop.last }}
      {%- endfor -%}
      where 1=0
    {%- elif not exists -%}
      select 1 where 1=0
    {%- else -%}
      select {{ columns | join(', ') }}
      from {{ relation }}
      {%- if where_sql %} where {{ where_sql | trim }}{%- endif -%}
    {%- endif -%}
  {%- endset %}

  {% if single_line %}
    {{ return(sql
      | replace('\n',' ')
      | replace('\r',' ')
      | replace('\t',' ')
      | trim) }}
  {% else %}
    {{ return(sql) }}
  {% endif %}
{% endmacro %}
