{{
    config(
        materialized='table',
        unique_key=['plan'],
        on_schema_change='fail',
        tags=['operations','daily-12pm']
    )
}}

with plan_group as (
    select
        distinct pc.id as plan,
        country,
        CASE
            WHEN gpa.grupo IS NOT NULL THEN grupo
            WHEN lower(nice_name) LIKE '%plan-a' THEN 'plan-a'
            WHEN lower(nice_name) LIKE '%plan-b' THEN 'plan-b'
            WHEN lower(nice_name) LIKE '%plan-c' THEN 'plan-c'
            WHEN lower(nice_name) LIKE '%plan-free' THEN 'freemium'
            WHEN lower(nice_name) LIKE '%plan-basico' THEN 'lojinha'
            WHEN lower(nice_name) LIKE '%plano-basico' THEN 'lojinha'
            WHEN lower(nice_name) LIKE '%mx-enterprise' THEN 'enterprise'
            WHEN lower(nice_name) LIKE '%plan-empresarial' THEN 'enterprise'
            WHEN lower(nice_name) LIKE '%enterprise' THEN 'enterprise'
            ELSE 'unknown'
        END AS grupo,
        CASE 
            WHEN pc.id IN (681,682,683,684) THEN 0
            WHEN pc.id <= 2575 THEN 1
            ELSE 0
        END AS before_freemium_launch,
        gpa.namev2,
        pc.context as plan_context
    from {{ source("dp_moltres", "mwp_plans_countries") }} pc
        left join {{ source("dp_moltres", "mwp_plans") }} p
            on pc.plan = p.id
        left join {{ source("dp_data_manual", "operations__grouping_plans_aux") }} gpa
            on pc.id = gpa.plan
)
select 
    plan,
    grupo,
    before_freemium_launch,
    CASE
        WHEN namev2 IS NOT NULL THEN namev2
        -- Group: enterprise
        WHEN grupo = 'enterprise' AND country IN ('AR', 'CL', 'CO', 'MX') THEN 'evolucion'
        WHEN grupo = 'enterprise' AND country = 'BR' THEN 'next'
        -- Group: freemium
        WHEN grupo = 'freemium' AND country = 'AR' THEN 'plan-inicial'
        WHEN grupo = 'freemium' AND country = 'BR' THEN 'plan-comeco'
        WHEN grupo = 'freemium' AND country = 'MX' THEN 'plan-gratis'
        WHEN grupo = 'freemium' AND country = 'CL' THEN 'freemium'
        -- Group: lojinha
        WHEN grupo = 'lojinha' THEN 'plan-basico'  -- Same for all
        -- Group: plan-a
        WHEN grupo = 'plan-a' AND country IN ('AR', 'CO') THEN 'plan-esencial'
        WHEN grupo = 'plan-a' AND country = 'BR' THEN 'plan-essencial'
        WHEN grupo = 'plan-a' AND country = 'CL' THEN 'plan-full'
        WHEN grupo = 'plan-a' AND country = 'MX' THEN 'plan-basico'
        -- Group: plan-b
        WHEN grupo = 'plan-b' AND country IN ('AR', 'CO', 'BR') THEN 'plan-impulso'
        WHEN grupo = 'plan-b' AND country = 'CL' THEN 'plan-plus'
        WHEN grupo = 'plan-b' AND country = 'MX' THEN 'plan-tiendanube'
        -- Group: plan-c
        WHEN grupo = 'plan-c' AND country IN ('AR', 'BR', 'CO') THEN 'plan-escala'
        WHEN grupo = 'plan-c' AND country IN ('CL', 'MX') THEN 'plan-avanzado'
        -- Group: zero-fee
        WHEN grupo = 'zero-fee' THEN 'colaboradores' -- Same for all
    END AS namev2,
    plan_context,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by
from 
    plan_group pg; 
