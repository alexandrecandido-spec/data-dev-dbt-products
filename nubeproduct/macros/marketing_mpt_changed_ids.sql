-- creado por sofia.torres@tiendanube.com
{% macro marketing_mpt_changed_ids(last_upd_cte='baseline', lookback_days=7, sources=[]) -%}
{#-
  Emite una CTE llamada `changed_ids` con los store_id que cambiaron en cualquier upstream
  dentro de una ventana de lookback días desde `last_upd` (tomado de la CTE `baseline`).

  Parámetros:
    - last_upd_cte: nombre de la CTE que expone `last_upd` (timestamp).
    - lookback_days: tamaño de la ventana hacia atrás (int).
    - sources: lista de structs con una key `sql` que devuelve:
         SELECT store_id, updated_on FROM <origen>

  Ejemplo de uso:
    {% set lookback = var('marketing_mpt_lookback_days', 7) %}
    {{ marketing_mpt_changed_ids(
         last_upd_cte='baseline',
         lookback_days=lookback,
         sources=[
           {"sql": "select cast(store_id as bigint) store_id, max(sys_audit_updated_on) updated_on from " ~ ref('marketing__acquisition__project_ms_base__domain') ~ " group by 1"},
           {"sql": "select cast(store_id as bigint) store_id, sys_audit_updated_on as updated_on from " ~ ref('s__attributes__store_core__ref')},
           {"sql": "select cast(store_id as bigint) store_id, sys_audit_updated_on as updated_on from " ~ ref('s__lifecycle__store_status__ref')},
           {"sql": "select cast(store_id as bigint) store_id, max(sys_audit_updated_on) updated_on from " ~ ref('marketing_attribution_model') ~ " group by 1"}
         ]
    ) }}

  Luego:
    , src as (
      {% if is_incremental() %}
        select s.* from src_all s inner join changed_ids c using (store_id)
      {% else %}
        select * from src_all
      {% endif %}
    )
-#}

changed_ids as (
  {% if sources | length > 0 %}
    {% for s in sources %}
      select cast(src.store_id as bigint) as store_id
      from ( {{ s.sql }} ) src, {{ last_upd_cte }} b
      where cast(src.updated_on as timestamp) >= b.last_upd - INTERVAL {{ lookback_days }} DAY
      {% if not loop.last %}union{% endif %}
    {% endfor %}
  {% else %}
    select cast(null as bigint) as store_id where 1=0
  {% endif %}
)
{%- endmacro %}

