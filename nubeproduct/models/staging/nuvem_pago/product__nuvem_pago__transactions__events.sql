{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['transaction_id'],
    on_schema_change = 'fail',
    tags = ['product','daily-8am']
) }}

with transactions as (
  select
    id as transaction_id
    ,chargeid as charge_id
    ,externalorderid as order_id
    ,status
    ,paymentmethod as payment_method
    ,amount
  from {{ source('stg_nuvem_pago_transactions', 'transactions') }}
)
select 
    t.*
    ,current_timestamp as sys_audit_created_on
    ,'data-dev-dbt-products' as sys_audit_created_by
    ,current_timestamp as sys_audit_updated_on
    ,'data-dev-dbt-products' as sys_audit_updated_by
from transactions t
{% if is_incremental() %}
  WHERE
  transaction_id not in (select transaction_id from {{ this }} )
{% endif %}