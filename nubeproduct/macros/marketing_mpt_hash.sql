-- creado por sofia.torres@tiendanube.com
-- Hash genérico de columnas (null-safe y portable)
-- Usa concat_ws con '|' y castea todo a string del motor actual.
{% macro mpt_hash(cols) -%}
md5(
  concat_ws(
    '|'
    {%- for c in cols %}
    , coalesce(cast({{ c }} as {{ dbt.type_string() }}), '')
    {%- endfor -%}
  )
)
{%- endmacro %}

-- Surrogate key / natural key con el mismo criterio
{% macro mpt_surrogate_key(cols) -%}
{{ mpt_hash(cols) }}
{%- endmacro %}

-- Wrappers con prefijo "marketing_" para mantener consistencia
{% macro marketing_mpt_hash(cols) -%}
  {{ mpt_hash(cols) }}
{%- endmacro %}

{% macro marketing_mpt_surrogate_key(cols) -%}
  {{ mpt_surrogate_key(cols) }}
{%- endmacro %}
