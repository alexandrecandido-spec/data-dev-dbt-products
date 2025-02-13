{% macro add_audit_columns() %}
    {% if not is_incremental()%}
        current_timestamp AS sys_audit_created_on,
        'data-dev-dbt-products' AS sys_audit_created_by,
    {% endif %}
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
{% endmacro %}