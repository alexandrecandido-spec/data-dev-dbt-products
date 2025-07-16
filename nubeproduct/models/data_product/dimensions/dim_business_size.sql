{{
    config(
        materialized='incremental',
        unique_key=['business_size_id'],
        on_schema_change='fail',
        tags=['daily-4am']
    )
}}

{{ generate_surrogate_dimension
(
    source_relation=source('stg_moltres','mwp_store_settings'),
    source_column='business_size',
    id_column='business_size_id',
    name_column='business_size_name',
    extra_columns=[],
    column_aliases={},
    source_filter="",
    fixed_values=[(-1, 'Not Informed'), (-2, 'Not Applicable')],
    passthrough_ids=false,
    audit_user='data-dev-dbt-products'
) }}