{% macro required_docs(models=None, model_name=None) %}
  {% if not execute %}
    {% do return("No-op in parse time") %}
  {% endif %}

  {# ---------------- Configurables por vars ---------------- #}
  {% set fail_on_error = var('required_docs_fail_on_error', true) %}
  {% set skip_models   = var('required_docs_skip_models', []) %}
  {% set models_var    = var('required_docs_models', none) %}

  {# ---------------- Normalización de targets ---------------- #}
  {# Prioridad: args > var #}
  {% if models is none and model_name is not none %}
    {% set models = model_name %}
  {% endif %}
  {% if models is none and models_var is not none %}
    {% set models = models_var %}
  {% endif %}

  {% set targets = none %}
  {% if models is not none %}
    {% if models is string %}
      {# admite "m1,m2 , m3" #}
      {% set models_list = models.split(',') | map('trim') | list %}
    {% elif models is iterable %}
      {% set models_list = models %}
    {% else %}
      {% set models_list = [models] %}
    {% endif %}
    {% set targets = models_list | map('lower') | list %}
  {% endif %}

  {# ---------------- Métricas ---------------- #}
  {% set total = 0 %}
  {% set ok = 0 %}
  {% set failures = [] %}

  {% if targets is none %}
    {% do log("🔎 required_docs: verificando descripciones y cobertura de columnas en TODOS los modelos…", info=true) %}
  {% else %}
    {% do log("🔎 required_docs: verificando solo los modelos: " ~ (targets | join(', ')), info=true) %}
  {% endif %}

  {% for node in graph.nodes.values()
       if node.resource_type == 'model'
       and node.package_name == project_name
       and (targets is none or (node.name | lower) in targets) %}

    {# --- Ignorar intermediate y ephemeral (sin imprimir) --- #}
    {% set path_str = (node.path or '') %}
    {% set fqn_list = (node.fqn or []) %}
    {% set is_ephemeral = (node.config.materialized == 'ephemeral') %}
    {% set is_intermediate = ('/intermediate/' in path_str) or ('intermediate' in fqn_list) %}
    {% if is_intermediate or is_ephemeral %}
      {% continue %}
    {% endif %}

    {# --- Ignorar por nombre (sin imprimir) --- #}
    {% if node.name in skip_models %}
      {% continue %}
    {% endif %}

    {% set total = total + 1 %}

    {# 1) description del modelo #}
    {% set model_desc = (node.description or '') | trim %}
    {% set model_has_desc = (model_desc != '') %}

    {# 2) columnas declaradas y sus descriptions #}
    {% set declared_cols_dict = node.columns or {} %}
    {% set declared_cols = declared_cols_dict.keys() | list %}
    {% set missing_desc_cols = [] %}
    {% for col_name, col in declared_cols_dict.items() %}
      {% set cdesc = (col.description or '') | trim %}
      {% if cdesc == '' %}
        {% do missing_desc_cols.append(col_name) %}
      {% endif %}
    {% endfor %}

    {# 3) columnas físicas en el catálogo/metastore #}
    {% set physical_cols = [] %}
    {% set rel = adapter.get_relation(
         database=node.database,
         schema=node.schema,
         identifier=node.alias
    ) %}
    {% if rel is not none %}
      {% set cols_in_rel = adapter.get_columns_in_relation(rel) %}
      {% for c in cols_in_rel %}
        {% do physical_cols.append(c.name) %}
      {% endfor %}
    {% else %}
      {% set cols_in_rel = [] %}
    {% endif %}

    {# Normalizar para comparar sin problemas de casing #}
    {% set physical_lower = physical_cols | map('lower') | list %}
    {% set declared_lower = declared_cols | map('lower') | list %}

    {# 3a) Físicas NO declaradas en schema.yml -> ERROR #}
    {% set missing_in_schema = [] %}
    {% for pc in physical_cols %}
      {% if pc | lower not in declared_lower %}
        {% do missing_in_schema.append(pc) %}
      {% endif %}
    {% endfor %}

    {# 3b) Declaradas que NO existen físicamente -> WARNING #}
    {% set declared_not_physical = [] %}
    {% for dc in declared_cols %}
      {% if dc | lower not in physical_lower %}
        {% do declared_not_physical.append(dc) %}
      {% endif %}
    {% endfor %}

    {# Resultado del modelo #}
    {% set has_errors = (not model_has_desc) or (missing_desc_cols | length > 0) or (missing_in_schema | length > 0) %}

    {% if not has_errors %}
      {% set ok = ok + 1 %}
      {% if targets is not none %}
        {% do log("✅ " ~ node.name ~ " — modelo y columnas ok", info=true) %}
      {% endif %}
      {% if declared_not_physical | length > 0 %}
        {% do log("⚠️  " ~ node.name ~ " — columnas declaradas que no existen físicamente: " ~ (declared_not_physical | join(', ')), info=true) %}
      {% endif %}
    {% else %}
      {% set msg = "❌ " ~ node.name ~ " — " %}
      {% if not model_has_desc %}{% set msg = msg ~ "[sin description de modelo] " %}{% endif %}
      {% if missing_desc_cols | length > 0 %}{% set msg = msg ~ "descriptions faltantes: " ~ (missing_desc_cols | join(', ')) ~ " " %}{% endif %}
      {% if missing_in_schema | length > 0 %}{% set msg = msg ~ "no declaradas en schema.yml: " ~ (missing_in_schema | join(', ')) ~ " " %}{% endif %}
      {% do log(msg | trim, info=true) %}
      {% if declared_not_physical | length > 0 %}
        {% do log("⚠️  columnas declaradas que no existen físicamente: " ~ (declared_not_physical | join(', ')), info=true) %}
      {% endif %}
      {% do failures.append({
        'unique_id': node.unique_id,
        'name': node.name,
        'path': node.path,
        'missing_model_description': (not model_has_desc),
        'missing_column_descriptions': missing_desc_cols,
        'missing_in_schema_yml': missing_in_schema,
        'declared_but_not_physical': declared_not_physical
      }) %}
    {% endif %}
  {% endfor %}

  {% set summary = "📊 Resumen — " ~ ok ~ " OK / " ~ (total - ok) ~ " con pendientes (de " ~ total ~ " modelos)" %}
  {% do log(summary, info=true) %}

  {% if fail_on_error and (failures | length > 0) %}
    {% do exceptions.raise_compiler_error("Hay problemas de documentación/cobertura de columnas. Revisá los logs.") %}
  {% endif %}

  {{ return(failures) }}
{% endmacro %}
