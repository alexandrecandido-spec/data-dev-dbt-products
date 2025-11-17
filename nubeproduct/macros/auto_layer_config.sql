{% macro tier_by_prefix() %}
  {# En modelos, 'model' está disponible en compile-time #}
  {% set name = model.name %}
  {% if name.startswith('g__') %}
    {{ config(meta={'openmetadata': {'tier': 'Tier.Gold'}}) }}
  {% elif name.startswith('s__') %}
    {{ config(meta={'openmetadata': {'tier': 'Tier.Silver'}}) }}
  {% else %}
    {{ config(meta={'openmetadata': {'tier': 'Tier.Unknown'}}) }}
  {% endif %}
{% endmacro %}
