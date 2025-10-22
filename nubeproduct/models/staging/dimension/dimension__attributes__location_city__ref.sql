{{
    config(
        materialized='incremental',
        unique_key=['city_id'],
        on_schema_change='fail',
        tags=['dimensions','manual']
    )
}}

{{ generate_surrogate_dimension
(
    source_relation=ref('_int_dim_location_city__union_cities'),
    source_column=['city_name'],
    id_column='city_id',
    name_column=['city_name'],
    extra_columns=['city_id_nk','state_id','region_id','country_id'],
    array_columns=[],
    column_aliases={},
    source_filter="",
    fixed_values=[(-1, 'Not Informed'), (-2, 'Not Applicable')],
    passthrough_ids=false,
    audit_user='data-dev-dbt-products'
) }}