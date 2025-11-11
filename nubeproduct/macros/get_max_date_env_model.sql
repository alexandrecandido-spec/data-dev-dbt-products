-- macros/get_max_date_env_model.sql
{% macro get_max_date_env_model(
    domain,
    table_name,
    date_field='base_date',
    period_value=1,
    period_unit='week',
    catalog_override=None,
    quote_identifiers=False,
    fallback_start=None,
    fallback_end=None
) %}

  {# 1) Monta FQN a partir do profile atual #}
  {% set dom = (domain | lower | trim) %}
  {% set db  = (catalog_override or target.catalog) %}
  {% set sc  = target.schema ~ '_' ~ dom %}         {# testing_product | data_product #}
  {% set idf = table_name %}

  {% if quote_identifiers %}
    {% set fqn = '`' ~ db ~ '`.`' ~ sc ~ '`.`' ~ idf ~ '`' %}
  {% else %}
    {% set fqn = db ~ '.' ~ sc ~ '.' ~ idf %}
  {% endif %}

  {# 2) Fases de compile x execute #}
  {% if not execute %}
    {% if fallback_start and fallback_end %}
      {{ return("BETWEEN DATE('" ~ fallback_start ~ "') AND DATE('" ~ fallback_end ~ "')") }}
    {% else %}
      {{ return("1=0") }}
    {% endif %}
  {% endif %}

  {# 3) Existe? #}
  {% set rel = adapter.get_relation(database=db, schema=sc, identifier=idf) %}
  {% if rel is none %}
    {% if fallback_start and fallback_end %}
      {{ return("BETWEEN DATE('" ~ fallback_start ~ "') AND DATE('" ~ fallback_end ~ "')") }}
    {% else %}
      {{ return("1=0") }}
    {% endif %}
  {% endif %}

  {# 4) Pega a max_date com CAST no agregado (não na coluna) #}
  {% set q %}
    select cast(max({{ date_field }}) as date) as max_date
    from {{ fqn }}
  {% endset %}
  {% set res = run_query(q) %}
  {% set max_date = (res and res.columns and res.columns[0].values() and res.columns[0].values()[0]) %}

  {# 5) Vazio? -> fallback #}
  {% if not max_date %}
    {% if fallback_start and fallback_end %}
      {{ return("BETWEEN DATE('" ~ fallback_start ~ "') AND DATE('" ~ fallback_end ~ "')") }}
    {% else %}
      {{ return("1=0") }}
    {% endif %}
  {% endif %}

  {# 6) Calcula janela em Jinja, retornando BETWEEN "cru" #}
  {% if max_date is string %}
    {% set base = modules.datetime.datetime.strptime(max_date, '%Y-%m-%d') %}
  {% else %}
    {% set base = modules.datetime.datetime.combine(max_date, modules.datetime.datetime.min.time()) %}
  {% endif %}

  {% set unit = period_unit | lower %}
  {% if unit in ['day','days'] %}
    {% set end = base + modules.datetime.timedelta(days=period_value) %}
  {% elif unit in ['week','weeks'] %}
    {% set end = base + modules.datetime.timedelta(weeks=period_value) %}
  {% elif unit in ['month','months'] %}
    {# mês aproximado; se quiser calendário exato, calcule no SQL consumidor com add_months #}
    {% set end = base + modules.datetime.timedelta(days=30 * period_value) %}
  {% else %}
    {% do exceptions.raise_compiler_error("Invalid period_unit: " ~ period_unit) %}
  {% endif %}

  {{ return("BETWEEN DATE('" ~ base.date() ~ "') AND DATE('" ~ end.date() ~ "')") }}
{% endmacro %}
