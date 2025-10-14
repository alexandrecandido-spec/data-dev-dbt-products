{% macro format_username(id_col, first_name_col, last_name_col) %}
{# Format username: "First Last" or "First" or "Last" or "User-{id}" #}
coalesce(
    case
        when nullif(trim(cast({{ first_name_col }} as string)), '') is not null
            and nullif(trim(cast({{ last_name_col }} as string)), '') is not null
                then concat(trim(cast({{ first_name_col }} as string)), ' ', trim(cast({{ last_name_col }} as string)))
        when nullif(trim(cast({{ first_name_col }} as string)), '') is not null
            then trim(cast({{ first_name_col }} as string))
        when nullif(trim(cast({{ last_name_col }} as string)), '') is not null
            then trim(cast({{ last_name_col }} as string))
    end,
    concat('User-', cast({{ id_col }} as string))
)
{% endmacro %}

