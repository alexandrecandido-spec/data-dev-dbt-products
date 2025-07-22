{{
    config(
        materialized='incremental',
        unique_key=['group_id'],
        on_schema_change='fail',
        tags=['daily-4am']
    )
}}

{{ generate_surrogate_dimension
(
    source_relation=ref('_int_dim_group_plan__json_plan_id_nk'),
    source_column=['group_name', 'group_desc'],
    id_column='group_id',
    name_column=['group_name', 'group_desc'],
    extra_columns=['group_order_id', 'plan_id_nk'],
    array_columns=['plan_id_nk'],
    column_aliases={},
    source_filter="",
    fixed_values=[(-1, 'Not Informed'), (-2, 'Not Applicable')],
    passthrough_ids=false,
    audit_user='data-dev-dbt-products'
) }}