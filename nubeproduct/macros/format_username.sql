{% macro format_username(id_col, first_name_col, last_name_col) %}
{# Format username: "First Last" or "First" or "Last" or "User-{id}" #}
(
    with names as (
        select
            nullif(trim(cast({{ first_name_col }} as string)), '') as first_name,
            nullif(trim(cast({{ last_name_col }} as string)), '') as last_name,
            cast({{ id_col }} as string) as user_id
    )

    select coalesce(
        case
            when first_name is not null and last_name is not null then first_name || ' ' || last_name
            when first_name is not null then first_name
            when last_name is not null then last_name
        end,
        'User-' || user_id
    ) as name
    from names
)
{% endmacro %}

