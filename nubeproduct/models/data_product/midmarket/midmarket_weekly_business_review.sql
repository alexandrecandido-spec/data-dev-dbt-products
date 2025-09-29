-- Owner: Guille De Felice

{{
    config(
        materialized='incremental',
        unique_key=['date_from', 'store_id'],
        incremental_strategy='append',
        on_schema_change='fail',
        tags=['weekly-monday-9am']
    )
}}

-- Last WBR Stores (Historical Postgres)
{% if not is_incremental() %}
with postgres_last_week_stores as (
    select 
        store_id
    from 
        {{ ref('_int_midmarket_wbr_mbr__wbr_clean') }}
    where 
        date_from = (SELECT max(date_from) FROM {{ ref('_int_midmarket_wbr_mbr__wbr_clean') }})
        and playbook not in ('Effective churn', 'Out of portfolio')
    )
{% endif %}

-- Last WBR Stores
{% if is_incremental() %}
with last_week_stores as (
    select 
        store_id
    from 
        {{ this }}
    where 
        date_from = (SELECT max(date_from) FROM {{ this }})
        and playbook not in ('Effective churn', 'Out of portfolio')
    )
{% endif %}

-- Historical Postgres
{% if not is_incremental() %}
SELECT *
FROM {{ ref('_int_midmarket_wbr_mbr__wbr_clean') }}

UNION ALL
{% endif %}

-- Incremental 
SELECT 
    CAST(date_trunc('week', current_date) - interval '7' day AS DATE) as date_from,
    CAST(date_trunc('week', current_date) AS DATE) as date_to,
    d.store_id,
    TRIM(regexp_replace(d.hubspot_owner_id, '\\s*\\(Deactivated User\\)$', '')) AS rep,
    case
      when l.success_priority in ('1','2','3') then concat('Level ', l.success_priority)
      else 'No Level'
    end as level,
    case 
        when dealstage in ('Expansão','Expansion') then 'Expansion'
        when dealstage in ('Manutenção','Mantenimiento') then 'Maintenance'
        else dealstage
    end as playbook,
    st.status, 
    p.country,
    fg.franchise_group,
    COALESCE(m.main, true) as main, 
    CAST(lri.last_relevant_interaction AS DATE) as last_relevant_interaction,
    CAST(fg.last_group_interaction AS DATE) as last_group_interaction,
    st.days_since_last_relevant_interaction,
    p.plan_id,
    CAST(p.monthly AS INTEGER) as monthly,
    p.context,
    p.nice_name,
    CAST(ROUND(p.transaction_fee, 1) AS DECIMAL(30,1)) as transaction_fee,
    p.transaction_fee_type,
    case
      when gp.grupo = 'enterprise' then true 
      else false
    end as enterprise_plan, 
    pc.type_change,
    not_unknown_reason,
    CAST(COALESCE(fd.free_days, 0) AS INTEGER) as free_days
FROM 
    {{ source("dp_third_party", "midmarket_hubspot_deals") }} d
    inner join {{ ref('midmarket_success_stores') }} s
      on d.deal_id = s.deal_id
    left join {{ ref('_int_midmarket_wbr_mbr__level') }} l
      on d.deal_id = l.deal_id
    left join {{ ref('_int_midmarket_wbr_mbr__last_relevant_interaction') }} lri
      on d.store_id = lri.store_id
    left join {{ ref('_int_midmarket_wbr_mbr__status') }} st
      on d.store_id = st.store_id 
    left join {{ ref('_int_midmarket_wbr_mbr__franchise_group') }} fg
      on d.store_id = fg.store_id  
    left join {{ ref('_int_midmarket_wbr_mbr__main') }} m
      on d.store_id = m.store_id       
    left join {{ ref('_int_midmarket_wbr_mbr__plan') }} p
      on d.store_id = p.store_id
    left join {{ ref('_int_midmarket_wbr_mbr__type_change') }} pc
      on d.store_id = pc.store_id
      and pc.periodicity = 'weekly'
    left join {{ ref('operations_grouping_plans') }} gp
      on p.plan_id = gp.plan
    left join {{ ref('_int_midmarket_wbr_mbr__free_days') }} fd
      on d.store_id = fd.store_id
      and fd.periodicity = 'weekly'
WHERE 
    {% if is_incremental() %}
    (s.in_portfolio = true
        OR s.store_id in (select store_id from last_week_stores))
    and CAST(date_trunc('week', current_date) - interval '7' day AS DATE) > (
        SELECT max(date_from) 
        FROM {{ this }} 
        )
    {% endif %}

    {% if not is_incremental() %}
    (s.in_portfolio = true
        OR s.store_id in (select store_id from postgres_last_week_stores))
    and CAST(date_trunc('week', current_date) - interval '7' day AS DATE) > (
        SELECT max(date_from) 
        FROM {{ ref('_int_midmarket_wbr_mbr__wbr_clean') }}
        )
    {% endif %}