{{
    config(
        materialized='incremental',
        unique_key=['vertical_id'],
        on_schema_change='fail',
        tags=['daily-4am']
    )
}}

{{ generate_surrogate_dimension
(
    source_relation=source('stg_moltres','mwp_store_settings'),
    source_column=['type'],
    id_column='vertical_id',
    name_column=['vertical_name'],
    extra_columns=[],
    array_columns=[],
    column_aliases={'vertical_name': 'type'},
    source_filter="type NOT IN ('a')",
    fixed_values=[(-1, 'Not Informed'), (-2, 'Not Applicable')],
    passthrough_ids=false,
    audit_user='data-dev-dbt-products'
) }}