-- depends_on: {{ ref('fintech__lending__installment_present_value__snapshot_daily') }}

{{
  config(
    materialized='incremental',
    incremental_strategy='merge',
    partition_by=['year_month_day_code'],
    on_schema_change='fail',
    tags=['fintech','daily-10am'],
    pre_hook=[
      "{% if is_incremental() %}
         DELETE FROM {{ this }} WHERE year_month_day_code >= 
         (SELECT coalesce(MAX(CAST(date_format(DATE(data_ref), 'yyyyMMdd') AS INT)), 0) 
          FROM {{ ref('fintech__lending__installment_present_value__snapshot_daily') }})
         {% endif %}"
    ]
  )
}}

with active_contracts as (
    select 
        CAST(hub_contract_id AS STRING) as hub_contract_id, 
        id as contract_id
    from {{ ref('fintech_contracts') }}
    where finished_at is null
)
select
    current_date as data_ref,
    c.hub_contract_id,
    c.contract_id,   
    case
        when i.installments_overdue > 0 then 'Overdue'
        when i.installments_open > 0 and i.installments_paid = 0 then 'Grace Period'
        else 'On Time'
    end as contract_status, 
    a.overdue_start_date,
    a.days_overdue,
    a.original_total,
    a.original_paid,
    a.original_overdue,
    a.original_open,
    COALESCE(p.present_overdue, 0) as present_overdue,
    COALESCE(p.present_open, 0) as present_open,
    COALESCE(ROUND((p.present_overdue + a.original_open),2), 0) as current_value,
    a.principal_total,
    a.principal_paid,
    a.principal_overdue,
    a.principal_open,
    a.interest_total,
    a.interest_paid,
    a.interest_overdue,
    a.interest_open,
    i.installments_paid,
    i.installments_overdue,
    i.installments_open,
    CAST(date_format(current_date, 'yyyyMMdd') AS INT) AS year_month_day_code,
    'data-dev-dbt-products' AS sys_audit_created_by,
    CURRENT_TIMESTAMP AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_updated_by,
    CURRENT_TIMESTAMP AS sys_audit_updated_on    
from active_contracts c
left join {{ ref('_int_fintech__grouped_installments_values') }} a on c.hub_contract_id = a.hub_contract_id
left join {{ ref('_int_fintech__installments_counts') }} i         on c.hub_contract_id = i.hub_contract_id
left join {{ ref('_int_fintech__present_values') }}  p             on c.hub_contract_id = p.hub_contract_id