{{ config(
    materialized = 'table',
    tags = ['daily-9am']
) }}

SELECT
    member_id,
    member_name,
    member_email,
    
    -- Data de criação do membro (Apenas Data)
    date(created_date) as created_at,

    phone_number,
    
    group_id,
    group_name,
    group_created_at,
    
    -- CORREÇÃO AQUI: Transformando a expiração em DATA pura
    date(group_expires_at) as group_expires_at

FROM {{ ref('int_curseduca__member_details') }}