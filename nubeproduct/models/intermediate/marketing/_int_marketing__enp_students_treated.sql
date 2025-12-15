{{ config(
    materialized='ephemeral',
    schema='marketing'
) }}

with base as (
    select
        name,
        email,
        to_date(createdAt)   as created_date,
        situation,
        to_date(updatedAt)   as updated_date,
        to_date(lastAccess)  as last_access_date
    from {{ ref('marketing__enp_students') }}
)

select * from base
