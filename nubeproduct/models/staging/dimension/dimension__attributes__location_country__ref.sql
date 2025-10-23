{{
    config(
        materialized='incremental',
        unique_key=['country_id'],
        on_schema_change='fail',
        tags=['dimensions','daily-4am']
    )
}}

{{ generate_surrogate_dimension
(
    source_relation=source('stg_moltres','mwp_countries'),
    source_column=['name_en'],
    id_column='country_id',
    name_column=['country_name'],
    extra_columns=['country_code'],
    array_columns=[],
    column_aliases={'country_id': 'id','country_code': 'code','country_name': 'name_en'},
    source_filter="",
    fixed_values=[(-1, 'Not Informed'), (-2, 'Not Applicable')],
    passthrough_ids=true,
    audit_user='data-dev-dbt-products'
) }}