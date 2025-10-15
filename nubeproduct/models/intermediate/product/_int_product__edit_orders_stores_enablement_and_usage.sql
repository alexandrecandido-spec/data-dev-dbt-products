select
    msi.store_id,
    msi.state,
    msi.country,
    msi.currency,
    msi.current_segment,
    msi.first_payment,
    msi.churned_at,
    gp.grupo plan_name,
    msi.created_at,
    msi.verified,
    e.has_edit_orders_available,
    e.edit_orders_available_at,
    f.edit_orders_user,
    f.edit_first_use,
    f.edit_last_use,
    f.edit_count,
    -- Combined audit field for all sources in this model
    GREATEST(
        COALESCE(msi.sys_audit_updated_on, '1900-01-01'),
        COALESCE(e.sys_audit_updated_on, '1900-01-01'),
        COALESCE(f.sys_audit_updated_on, '1900-01-01'),
        COALESCE(gp.sys_audit_updated_on, '1900-01-01')
    ) as max_sys_audit_updated_on
FROM {{ ref('moltres__mwp_store_info') }} msi
LEFT JOIN {{ ref('operations_grouping_plans') }} gp on gp.plan = msi.plan
LEFT JOIN {{ ref('_int_product__edit_orders_stores_enabling_tag') }} e on e.related_id = msi.store_id
LEFT JOIN {{ ref('_int_product__edit_orders_stores_first_use') }} f on f.store_id = msi.store_id


    
