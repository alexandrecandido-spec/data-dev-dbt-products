{{
    config(
        materialized='incremental',
        unique_key='order_id',
        on_schema_change='fail'
    )
}}


WITH source AS (
    SELECT 
        TRY_CAST(order_id AS BIGINT) AS order_id,
        test_name,
        variant
    FROM {{ source('moltres', 'mwp_checkout_ab_tests') }}
    WHERE created_at > DATE_ADD(DAY, -31, CURRENT_DATE) 

    {% if is_incremental() %}

    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    AND sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ source('moltres','mwp_checkout_ab_tests') }} )

    {% endif %}
)

SELECT 
    *,
    CASE  
        WHEN variant = 'a'  THEN 'A: Control'
        WHEN variant = 'b'  THEN 'B: Treatment'
        WHEN variant = 'c'  THEN 'C: Treatment 2'
    END AS variant_name
FROM source