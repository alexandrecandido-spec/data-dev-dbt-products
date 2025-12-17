{{ config(
    materialized = 'table',
    tags = ['marketing', 'daily-9am']
) }}

SELECT
    id as member_id,
    name,             -- Essencial para o Intermediate
    email,            -- Essencial para o Intermediate
    createdAt as created_date, 
    updatedAt as updated_date
FROM {{ source('enp_curseduca', 'members') }}