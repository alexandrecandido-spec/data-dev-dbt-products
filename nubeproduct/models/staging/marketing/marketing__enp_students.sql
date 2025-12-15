{{ config(
    materialized='table',
    tags=['marketing', 'daily-9am']
) }}

select
    *
from raw.enp_curseduca.members
