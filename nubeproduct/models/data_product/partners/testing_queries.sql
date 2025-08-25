{{ 
    config(
        materialized = 'incremental',
        incremental_strategy = 'append',
        unique_key = ['partner_id','snapshot_date'],
        on_schema_change = 'fail',
        tags = ['weekly-monday-11am']
) }}