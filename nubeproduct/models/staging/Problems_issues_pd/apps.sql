{{ config(
    materialized = 'table',
    unique_key = 'app_id',
    partition_by = 'app_name',
    on_schema_change = 'fail',
    tags = ['daily-9am-9pm']
) }}

select 
    id as app_id
    ,handle as app_name
    ,partners_id
    ,categories_id
    ,app_type_id
    ,case when official = 1 then true else false end as is_official_app
    ,visibility
    ,date(created_at) as creation_date
    ,date(published_at) as published_date
    ,date(deleted_at) as deletion_date
    ,status as app_status
from {{ source('bronze_risk_ecosystem', 'apps') }}
