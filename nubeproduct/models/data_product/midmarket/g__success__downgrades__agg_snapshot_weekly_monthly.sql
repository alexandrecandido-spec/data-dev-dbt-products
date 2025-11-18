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
    {{ ref('_int_midmarket_downgrades__weekly_downgrades') }}

union all

select
    *
from
    {{ ref('_int_midmarket_downgrades__monthly_downgrades') }}