{# Afeta só o MERGE da materialização incremental durante o run (dbt 1.9.x) #}
{% macro default__get_incremental_merge_sql(args) -%}
  {% set target_relation        = args.get('target_relation') %}
  {% set temp_relation          = args.get('temp_relation') %}
  {% set unique_key             = args.get('unique_key') %}
  {% set dest_columns           = args.get('dest_columns') %}
  {% set incremental_predicates = args.get('incremental_predicates') %}

  {%- set DEST = 'DBT_INTERNAL_DEST' -%}
  {%- set SRC  = 'DBT_INTERNAL_SOURCE' -%}

  {# normaliza chave(s) #}
  {%- if unique_key is string -%}
    {%- set keys = [unique_key] -%}
  {%- else -%}
    {%- set keys = unique_key or [] -%}
  {%- endif -%}
  {%- set keyset = keys | map('lower') | list -%}

  {# ON com "=" (sem null-safe) #}
  {%- set on_parts = [] -%}
  {%- for k in keys -%}
    {%- set qk = adapter.quote(k) -%}
    {%- do on_parts.append(SRC ~ '.' ~ qk ~ ' = ' ~ DEST ~ '.' ~ qk) -%}
  {%- endfor -%}
  {%- if incremental_predicates is not none and (incremental_predicates | length) > 0 -%}
    {%- for p in incremental_predicates -%}
      {%- do on_parts.append(p) -%}
    {%- endfor -%}
  {%- endif -%}
  {%- set on_sql = (on_parts | join(' and ')) if (on_parts | length) > 0 else 'false' -%}

  {# colunas do destino (fallback para catálogo) #}
  {%- set cols = dest_columns if (dest_columns and (dest_columns | length) > 0) else adapter.get_columns_in_relation(target_relation) -%}
  {%- set all = [] -%}
  {%- for c in cols -%}
    {%- do all.append(c.name) -%}
  {%- endfor -%}

  {# merge_update_columns (opcional) #}
  {%- set upd_cfg = config.get('merge_update_columns') -%}
  {%- if upd_cfg is string -%}
    {%- set update_names = [upd_cfg] -%}
  {%- elif upd_cfg is sequence and (upd_cfg | length) > 0 -%}
    {%- set update_names = upd_cfg -%}
  {%- else -%}
    {%- set update_names = [] -%}
    {%- for n in all -%}
      {%- if (n | lower) not in keyset -%}
        {%- do update_names.append(n) -%}
      {%- endif -%}
    {%- endfor -%}
  {%- endif -%}

  {%- set q_all = [] -%}
  {%- for n in all -%}
    {%- do q_all.append(adapter.quote(n)) -%}
  {%- endfor -%}

  {%- set q_update = [] -%}
  {%- for n in update_names -%}
    {%- do q_update.append(adapter.quote(n)) -%}
  {%- endfor -%}

  {%- set update_pairs = [] -%}
  {%- for qc in q_update -%}
    {%- do update_pairs.append(qc ~ ' = ' ~ SRC ~ '.' ~ qc) -%}
  {%- endfor -%}
  {%- if update_pairs | length == 0 -%}
    {%- set fallback = none -%}
    {%- for n in all -%}
      {%- if (n | lower) not in keyset -%}
        {%- set fallback = adapter.quote(n) -%}
        {%- break -%}
      {%- endif -%}
    {%- endfor -%}
    {%- if fallback is none and keys | length > 0 -%}
      {%- set fallback = adapter.quote(keys[0]) -%}
    {%- endif -%}
    {%- set update_pairs = [ fallback ~ ' = ' ~ SRC ~ '.' ~ fallback ] -%}
  {%- endif -%}
  {%- set update_set = update_pairs | join(', ') -%}

  {%- set insert_cols = q_all | join(', ') -%}
  {%- set insert_vals = [] -%}
  {%- for qc in q_all -%}
    {%- do insert_vals.append(SRC ~ '.' ~ qc) -%}
  {%- endfor -%}
  {%- set insert_vals_csv = insert_vals | join(', ') -%}

  merge into {{ target_relation }} as {{ DEST }}
  using {{ temp_relation }} as {{ SRC }}
  on {{ on_sql }}
  when matched then update set
    {{ update_set }}
  when not matched then insert (
    {{ insert_cols }}
  ) values (
    {{ insert_vals_csv }}
  )
{%- endmacro %}