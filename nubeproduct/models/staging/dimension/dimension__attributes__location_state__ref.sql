{{
    config(
        materialized='incremental',
        unique_key=['state_id'],
        on_schema_change='fail',
        tags=['dimensions','manual']
    )
}}

{{ generate_surrogate_dimension
(
    source_relation=ref('_int_dim_location_state__add_attributes'),
    source_column=['state_name'],
    id_column='state_id',
    name_column=['state_name'],
    extra_columns=['state_code','region_id','country_id'],
    array_columns=[],
    column_aliases={},
    source_filter="",
    fixed_values=[(-1, 'Not Informed'), (-2, 'Not Applicable')],
    passthrough_ids=true,
    audit_user='data-dev-dbt-products'
) }}