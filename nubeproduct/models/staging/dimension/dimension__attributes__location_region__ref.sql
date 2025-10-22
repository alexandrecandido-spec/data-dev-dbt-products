{{
    config(
        materialized='incremental',
        unique_key=['region_id'],
        on_schema_change='fail',
        tags=['dimensions','manual']
    )
}}

{{ generate_surrogate_dimension
(
    source_relation=source("stg_data_manual", "dimensions__region"),
    source_column=['region_name'],
    id_column='region_id',
    name_column=['region_name'],
    extra_columns=['region_code','country_id'],
    array_columns=[],
    column_aliases={},
    source_filter="",
    fixed_values=[(-1, 'Not Informed'), (-2, 'Not Applicable')],
    passthrough_ids=true,
    audit_user='data-dev-dbt-products'
) }}