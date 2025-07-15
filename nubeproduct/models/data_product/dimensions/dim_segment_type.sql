{{
    config(
        unique_key=['segment_id'],
        on_schema_change='fail',
        tags=['manual']
    )
}}

{{ generate_surrogate_dimension
(
    source_relation=ref('dimensions__segment_type'),
    source_column='segment_name',
    id_column='segment_id',
    name_column='segment_name',
    extra_columns=['segment_order'],
    array_columns=[],
    column_aliases={},
    source_filter="",
    fixed_values=[],
    passthrough_ids=true,
    audit_user='data-dev-dbt-products'
) }}