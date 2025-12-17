{{ config(
    materialized = 'table',
    tags = ['marketing', 'daily-9am']
) }}

WITH source AS (
    -- Importante: O DBT precisa encontrar a definição desta source no arquivo YAML (Passo 2)
    SELECT * FROM {{ source('enp_curseduca', 'member_details') }}
),

cleaned_data AS (
    SELECT
        id as member_id,

        -- 1. Tratamento do Telefone
        CASE 
            WHEN phone LIKE '%undefined%' THEN NULL
            WHEN phone LIKE '%null%' THEN NULL
            WHEN length(phone) < 5 THEN NULL 
            ELSE phone 
        END as phone_number,

        -- 2. Tratamento do JSON
        from_json(
            groups, 
            'ARRAY<STRUCT<group:STRUCT<id:INT, name:STRING, expiresAt:TIMESTAMP>, externalReference:STRING, createdAt:TIMESTAMP>>'
        ) as groups_struct

    FROM source
)

SELECT
    member_id,
    phone_number,

    -- 3. Extração das novas colunas
    groups_struct[0].group.id as group_id,
    groups_struct[0].group.name as group_name,
    groups_struct[0].group.expiresAt as group_expires_at,
    date(groups_struct[0].createdAt) as group_created_at

FROM cleaned_data