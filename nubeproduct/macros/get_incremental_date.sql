{# =========================
# Helpers em escopo global
# ========================= #}

{% macro _period_start(d, period) -%}
  {%- set y = d.year -%}
  {%- set m = d.month -%}
  {%- if period in ['day','daily'] -%}
    {{ return(modules.datetime.datetime(y, m, d.day)) }}
  {%- elif period in ['week','weekly'] -%}
    {{ return(d - modules.datetime.timedelta(days=d.weekday())) }}
  {%- elif period in ['month','monthly'] -%}
    {{ return(modules.datetime.datetime(y, m, 1)) }}
  {%- elif period in ['quarter','quarterly'] -%}
    {%- set q0 = ((m - 1) // 3) * 3 + 1 -%}
    {{ return(modules.datetime.datetime(y, q0, 1)) }}
  {%- elif period in ['year','yearly','annually'] -%}
    {{ return(modules.datetime.datetime(y, 1, 1)) }}
  {%- elif period is none -%}
    {{ return(d) }}
  {%- else -%}
    {{ exceptions.raise_compiler_error("Unsupported back_trunc: " ~ period) }}
  {%- endif -%}
{%- endmacro %}

{% macro _period_end(d, period) -%}
  {%- set y = d.year -%}
  {%- set m = d.month -%}
  {%- if period in ['day','daily'] -%}
    {{ return(modules.datetime.datetime(y, m, d.day)) }}
  {%- elif period in ['week','weekly'] -%}
    {%- set ws = d - modules.datetime.timedelta(days=d.weekday()) -%}
    {{ return(ws + modules.datetime.timedelta(days=6)) }}
  {%- elif period in ['month','monthly'] -%}
    {%- if m == 12 -%}
      {%- set first_next = modules.datetime.datetime(y + 1, 1, 1) -%}
    {%- else -%}
      {%- set first_next = modules.datetime.datetime(y, m + 1, 1) -%}
    {%- endif -%}
    {{ return(first_next - modules.datetime.timedelta(days=1)) }}
  {%- elif period in ['quarter','quarterly'] -%}
    {%- set q0 = ((m - 1) // 3) * 3 + 1 -%}
    {%- set end_m = q0 + 2 -%}
    {%- if end_m == 12 -%}
      {%- set first_next = modules.datetime.datetime(y + 1, 1, 1) -%}
    {%- else -%}
      {%- set first_next = modules.datetime.datetime(y, end_m + 1, 1) -%}
    {%- endif -%}
    {{ return(first_next - modules.datetime.timedelta(days=1)) }}
  {%- elif period in ['year','yearly','annually'] -%}
    {{ return(modules.datetime.datetime(y, 12, 31)) }}
  {%- elif period is none -%}
    {{ return(d) }}
  {%- else -%}
    {{ exceptions.raise_compiler_error("Unsupported fwd_trunc: " ~ period) }}
  {%- endif -%}
{%- endmacro %}

{# =========================
# Macro principal
# ========================= #}

{% macro get_incremental_date(
    domain,
    table,
    date_field,
    fwd_value,
    fwd_unit,
    back_value=0,
    back_unit='day',
    fwd_trunc=None,
    back_trunc=None,
    force_date=None,
    catalog=None,
    quote=False,
    verbose=True
) %}

  {% set _fwd_val = (fwd_value | int) %}
  {% set _back_val = (back_value | int) %}
  {% set _fwd_unit = (fwd_unit | lower | trim) %}
  {% set _back_unit = (back_unit | lower | trim) %}
  {% set _fwd_trunc = (fwd_trunc | lower | trim) if fwd_trunc else none %}
  {% set _back_trunc = (back_trunc | lower | trim) if back_trunc else none %}

  {% set _force = force_date %}
  {% if _force in ['', 'None'] %}
    {% set _force = none %}
  {% endif %}

  {% set dom = (domain | lower | trim) %}
  {% set db  = (catalog or target.catalog) %}
  {% set sc  = target.schema ~ '_' ~ dom %}
  {% set idf = table %}
  {% if quote %}
    {% set fqn = '`' ~ db ~ '`.`' ~ sc ~ '`.`' ~ idf ~ '`' %}
  {% else %}
    {% set fqn = db ~ '.' ~ sc ~ '.' ~ idf %}
  {% endif %}

  {% if _force %}
    {% set base_start = modules.datetime.datetime.strptime(_force, '%Y-%m-%d') %}
  {% else %}
    {% if not execute %}
      {{ return("1=0") }}
    {% endif %}
    {% set rel = adapter.get_relation(database=db, schema=sc, identifier=idf) %}
    {% if rel is none %}
      {{ return("1=0") }}
    {% endif %}
    {% set q %}
      select cast(max({{ date_field }}) as date) as max_date
      from {{ fqn }}
    {% endset %}
    {% set res = run_query(q) %}
    {% set max_date = (res and res.columns and res.columns[0].values() and res.columns[0].values()[0]) %}
    {% if not max_date %}
      {{ return("1=0") }}
    {% endif %}
    {% if max_date is string %}
      {% set base_start = modules.datetime.datetime.strptime(max_date, '%Y-%m-%d') %}
    {% else %}
      {% set base_start = modules.datetime.datetime.combine(max_date, modules.datetime.datetime.min.time()) %}
    {% endif %}
  {% endif %}

  {# start (back) #}
  {% if _back_unit in ['day','days'] %}
    {% set start_dt = base_start - modules.datetime.timedelta(days=_back_val) %}
  {% elif _back_unit in ['week','weeks'] %}
    {% set start_dt = base_start - modules.datetime.timedelta(weeks=_back_val) %}
  {% elif _back_unit in ['month','months'] %}
    {% set start_dt = base_start - modules.datetime.timedelta(days=30 * _back_val) %}
  {% else %}
    {% do exceptions.raise_compiler_error("Invalid back_unit: " ~ back_unit) %}
  {% endif %}
  {% set start_dt = _period_start(start_dt, _back_trunc) %}

  {# end (fwd) #}
  {% if _fwd_unit in ['day','days'] %}
    {% set end_dt = base_start + modules.datetime.timedelta(days=_fwd_val) %}
  {% elif _fwd_unit in ['week','weeks'] %}
    {% set end_dt = base_start + modules.datetime.timedelta(weeks=_fwd_val) %}
  {% elif _fwd_unit in ['month','months'] %}
    {% set end_dt = base_start + modules.datetime.timedelta(days=30 * _fwd_val) %}
  {% else %}
    {% do exceptions.raise_compiler_error("Invalid fwd_unit: " ~ fwd_unit) %}
  {% endif %}
  {% set end_dt = _period_end(end_dt, _fwd_trunc) %}

  {% set between_sql = "BETWEEN DATE('" ~ start_dt.date() ~ "') AND DATE('" ~ end_dt.date() ~ "')" %}

  {% if verbose %}
    {% do log("get_incremental_date \u2192 get_date (" ~ base_start.date() ~ ") " ~ between_sql, info=True) %}
  {% endif %}

  {{ return(between_sql) }}

{% endmacro %}