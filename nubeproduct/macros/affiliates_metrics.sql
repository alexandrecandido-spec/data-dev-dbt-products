{% macro generate_metric_union(source_ref, metric_name, metric_columns) %}
/*
Esta macro gera um bloco SELECT para UNION ALL, 
preenchendo apenas a coluna de 'metric_name' com os dados da fonte.
*/

SELECT
    partner_id,
    country_code,
    is_store_blocked,
    new_seller,
    date,
    {% for col in metric_columns %}
    {% if col == metric_name %}
    -- Coluna principal (a ser selecionada da fonte)
    {{ col }} AS {{ col }}
    {% else %}
    -- Outras colunas (zeradas)
    0 AS {{ col }}
    {% endif %}
    {% if not loop.last %}
    ,
    {% endif %}
    {% endfor %}
FROM {{ ref(source_ref) }}
{% endmacro %}