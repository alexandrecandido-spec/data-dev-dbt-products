{{ config(
    materialized = 'ephemeral'
) }}

WITH members AS (
    SELECT *
    -- Ajustado para o nome padrão sugerido (verifique se você renomeou o arquivo!)
    FROM {{ ref('stg_curseduca__members') }} 
),

details AS (
    SELECT *
    FROM {{ ref('stg_curseduca__member_details') }}
)

SELECT
    m.member_id,
    m.member_name,   -- Garanta que no staging o alias seja member_name
    m.member_email,  -- Garanta que no staging o alias seja member_email
    m.created_at,    -- Garanta que no staging o alias seja created_at (padrão)
    
    d.phone_number,
    
    -- Colunas novas do JSON 
    d.group_id,
    d.group_name,
    d.group_created_at,
    d.group_expires_at

FROM members m
LEFT JOIN details d 
    ON m.member_id = d.member_id