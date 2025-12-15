{{ config(
    materialized='table',
    schema='marketing'
) }}

select
    name,
    email,
    created_date,
    updated_date,
    last_access_date,
    situation
from {{ ref('_int_marketing__enp_students_treated') }}
