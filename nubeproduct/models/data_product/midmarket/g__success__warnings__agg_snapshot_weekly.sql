-- Owner: Guille De Felice

{{
    config(
        materialized='incremental',
        unique_key=['date_from', 'deal_id'],
        incremental_strategy='append',
        on_schema_change='fail',
        tags=['weekly-monday-9am']
    )
}}

-- Historical Postgres
{% if not is_incremental() %}
SELECT *
FROM {{ ref('_int_midmarket_warnings__weekly_warnings_clean') }} 

UNION ALL
{% endif %}

-- Incremental 
SELECT
    date_from,
    date_to,
    deal_id,
    store_id,
    warning_root_cause_1,
    warning_root_cause_2,
    warning_summary,
    warning_type,
    competitor_identified,
    date_entered_warning,
    case 
        when date_exited_warning < date_entered_warning then null
        else date_exited_warning
    end as date_exited_warning
FROM 
    {{ ref('_int_midmarket_warnings__weekly_warnings')}} w
WHERE 
    {% if is_incremental() %}
    w.date_from > (
        SELECT max(date_from) 
        FROM {{ this }} 
        )
    {% endif %}

    {% if not is_incremental() %}
    w.date_from > (
        SELECT max(date_from) 
        FROM {{ ref('_int_midmarket_warnings__weekly_warnings_clean') }} 
        )
    {% endif %}