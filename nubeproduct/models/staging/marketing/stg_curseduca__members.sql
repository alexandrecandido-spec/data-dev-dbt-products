{{ config(
    materialized = 'table',
    tags = ['marketing', 'daily-9am']
) }}

SELECT
    id as member_id,
    name as member_name,        -- Padronizar para snake_case
    email as member_email,      -- Padronizar para bater com a outra tabela
    cast(createdAt as timestamp) as created_at, -- Casting explícito e snake_case
    cast(updatedAt as timestamp) as updated_at  -- Casting explícito e snake_case
FROM {{ source('enp_curseduca', 'members') }}