{{ config(
    alias='s__enp__members_details__ref',
    tags=['marketing', 'daily-9am'],
    materialized='table'
) }}

SELECT
    member_id,
    member_name,
    member_email,
    created_at,
    phone_number,
    
    -- Colunas de Grupo (que vieram do Intermediate)
    group_id,
    group_name,
    group_created_at,
    group_expires_at

FROM {{ ref('int_marketing__enp_members_joined') }}