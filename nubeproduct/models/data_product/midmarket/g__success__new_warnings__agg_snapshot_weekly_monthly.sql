-- Owner: Guille De Felice

{{
    config(
        materialized='table', 
        on_schema_change='fail',
        tags=['weekly-monday-930am-monthly-1st-11am']
    )
}}

select
    *
from
    {{ ref('_int_midmarket_warnings__weekly_new_warnings') }}

union all

select
    *
from
    {{ ref('_int_midmarket_warnings__monthly_new_warnings') }}