-- Macro: generate_surrogate_dimension.sql
-- Description: Generates an incremental dimension with stable surrogate keys, preserving fixed values and auditing creation and update metadata.
-- Parameters:

-- source_relation: The table or source reference containing the raw input data (use ref() or source()).
-- source_column: The name of the column used as the core business attribute (typically the name or label).
-- id_column: The name of the surrogate key column to be created or passed through.
-- name_column: The alias for the business name column in the dimension.
-- fixed_values: A list of static values with manually assigned IDs (e.g., [(-1, 'Not Informed')]).
-- audit_user: Name or identifier of the user/system responsible for the audit fields.
-- extra_columns: Additional columns to include in the dimension aside from id and name.
-- array_columns: List that identifies which columns are of type ARRAY so that they do not receive default values.
-- source_filter: Optional SQL filter (string) to limit the rows selected from the source_relation.
-- passthrough_ids: Boolean. If true, assumes the source_relation already includes a stable ID column.
-- column_aliases: Dictionary mapping source column names to target aliases, used to rename fields on ingest.

{% macro generate_surrogate_dimension
(
    source_relation,
    source_column,
    id_column,
    name_column,
    extra_columns=[],
    column_aliases={},
    array_columns=[],
    source_filter='',
    fixed_values=[],
    passthrough_ids=false,
    audit_user='data-dev-dbt-products'
) %}

{% set all_columns = [id_column, name_column] + extra_columns %}
{% set compound_key = [name_column] + extra_columns %}

WITH

{% if is_incremental() %}
existing_data AS 
(
  {{ get_existing_data(this, all_columns + ['sys_audit_created_on', 'sys_audit_created_by']) }}
),
{% else %}
existing_data AS 
(
  SELECT NULL AS {{ id_column }}, NULL AS {{ name_column }}{% for col in extra_columns %}, NULL AS {{ col }}{% endfor %}, NULL AS sys_audit_created_on, NULL AS sys_audit_created_by WHERE 1=0
),
{% endif %}

fixed_values AS 
(
  {% if fixed_values | length > 0 %}
    {% for id, name in fixed_values %}
      SELECT 
        {{ id }} AS {{ id_column }},
        '{{ name }}' AS {{ name_column }}
        {% for col in extra_columns %}
          , {% if col in array_columns %}
              CAST(NULL AS ARRAY<INT>) AS {{ col }}
            {% elif col.endswith('_id') or col.endswith('_id_nk') %}
              {{ id }} AS {{ col }}
            {% else %}
              '{{ name }}' AS {{ col }}
            {% endif %}
        {% endfor %}
      {% if not loop.last %} UNION ALL {% endif %}
    {% endfor %}
  {% else %}
    SELECT NULL AS {{ id_column }}, NULL AS {{ name_column }}{% for col in extra_columns %}, NULL AS {{ col }}{% endfor %} WHERE 1=0
  {% endif %}
),

source_values AS 
(
  SELECT DISTINCT
    {% if passthrough_ids %}{{ column_aliases.get(id_column, id_column) }} AS {{ id_column }}, {% endif %}
    {{ column_aliases.get(source_column, source_column) }} AS {{ name_column }}{% for col in extra_columns %}, {{ column_aliases.get(col, col) }} AS {{ col }}{% endfor %}
  FROM {{ source_relation }}
  WHERE {{ column_aliases.get(source_column, source_column) }} IS NOT NULL
  {% if source_filter %} AND {{ source_filter }}{% endif %}
),

new_values AS 
(
  SELECT
    {% if passthrough_ids %}{{ id_column }}, {% endif %}
    {{ compound_key | join(', ') }}
  FROM source_values
  {% if is_incremental() %}
  WHERE ({{ compound_key | join(', ') }}) NOT IN (SELECT {{ compound_key | join(', ') }} FROM existing_data)
  {% endif %}
),

{% if not passthrough_ids %}
  {% if is_incremental() %}
  max_id AS 
  (
    SELECT COALESCE(MAX({{ id_column }}), 0) AS current_max_id FROM existing_data WHERE {{ id_column }} > 0
  )
  {% else %}
  max_id AS 
  (
    SELECT 0 AS current_max_id
  )
  {% endif %},

  new_values_with_id AS 
  (
    SELECT
      ROW_NUMBER() OVER (ORDER BY {{ name_column }}) + m.current_max_id AS {{ id_column }},
      n.*
    FROM new_values n
    CROSS JOIN max_id m
  )
{% else %}
  new_values_with_id AS 
  (
    SELECT * FROM new_values
  )
{% endif %},

raw_dimension AS 
(
  SELECT {{ id_column }}, {{ name_column }}{% for col in extra_columns %}, {{ col }}{% endfor %} FROM fixed_values
  UNION ALL
  SELECT {{ id_column }}, {{ name_column }}{% for col in extra_columns %}, {{ col }}{% endfor %} FROM new_values_with_id
)

SELECT 
  *,
  current_timestamp AS sys_audit_created_on,
  '{{ audit_user }}' AS sys_audit_created_by,
  current_timestamp AS sys_audit_updated_on,
  '{{ audit_user }}' AS sys_audit_updated_by
FROM raw_dimension
ORDER BY {{ id_column }}

{% endmacro %}