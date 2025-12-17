{{ config(
    materialized = 'ephemeral'
) }}

WITH members AS (
    SELECT *
    -- Atenção: Confirme se o nome do arquivo de membros é este mesmo ou se você já renomeou para 'stg_curseduca__members'
    FROM {{ ref('stg_marketing__enp_members') }} 
),

details AS (
    SELECT *
    FROM {{ ref('stg_curseduca__member_details') }}
)

SELECT
    m.member_id,
    m.name AS member_name,
    m.email AS member_email,
    m.created_date,
    
    d.phone_number,
    
    -- AQUI ESTÁ A MUDANÇA:
    -- Pegamos as colunas limpas que você viu no Databricks
    d.group_id,
    d.group_name,       -- O nome real do grupo (ex: "Freemium...")
    d.group_created_at, -- A data de criação do vínculo com o grupo
    d.group_expires_at

FROM members m
LEFT JOIN details d 
    ON m.member_id = d.member_id