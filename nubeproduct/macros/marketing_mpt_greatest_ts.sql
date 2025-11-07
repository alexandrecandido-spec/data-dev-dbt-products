-- creado por sofia.torres@tiendanube.com
{% macro marketing_mpt_greatest_ts(ts_list) -%}
{#-
  Devuelve un GREATEST seguro entre timestamps, coalesceando cada uno a un sentinel.
  Uso: {{ marketing_mpt_greatest_ts(['col_a','col_b','col_c']) }}
-#}
{% if ts_list | length == 0 %}
  TIMESTAMP '1900-01-01'
{% else %}
  greatest(
    {%- for ts in ts_list -%}
      coalesce(cast({{ ts }} as timestamp), TIMESTAMP '1900-01-01'){% if not loop.last %},{% endif %}
    {%- endfor -%}
  )
{% endif %}
{%- endmacro %}
