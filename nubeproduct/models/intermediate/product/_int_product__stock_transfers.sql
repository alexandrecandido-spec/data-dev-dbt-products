with product_summary AS (
    select 
    stock_transfer_id,
    store_id,
    count(distinct product_id) products,
    count(distinct case when quantity_done > 0 then product_id end) products_transferred,
    count(distinct variant_id) variants,
    count(distinct case when quantity_done > 0 then variant_id end) variants_transferred,
    sum(quantity) quantity,
    sum(quantity_done) quantity_done,
    max(sys_audit_updated_on) max_sys_audit_updated_on
    from {{ source('int_catalog', 'mwp_stock_transfer_detail') }}
    group by 1,2
)

select 
t.id,
t.store_id,
msi.domain,
msi.country,
msi.current_segment,
msi.state,
p.grupo plan,
t.location_id,
date(l.createdAt) location_created_at,
date(l.deletedAt) location_deleted_at,
t.location_destination_id,
date(ld.createdAt) location_destination_created_at,
date(ld.deletedAt) location_destination_deleted_at,
t.transfer_mode,
t.status, 
t.extra_info,
date(t.created_at),
d.products products_to_transfer,
d.products_transferred,
d.variants variants_to_transfer,
d.variants_transferred,
d.quantity quantity_to_transfer,
d.quantity_done tranferred_quantity_done,
greatest(
    t.sys_audit_updated_on,
    d.max_sys_audit_updated_on,
    l.sys_audit_updated_on,
    ld.sys_audit_updated_on,
    msi.sys_audit_updated_on,
    p.sys_audit_updated_on
) as max_sys_audit_updated_on
FROM {{ source('int_catalog', 'mwp_stock_transfer') }} t
left join product_summary d ON d.stock_transfer_id = t.id
left join {{ ref('product__shipping_locations') }} l on t.location_id = l.id
left join {{ ref('product__shipping_locations') }} ld on t.location_destination_id = ld.id
left join {{ ref('moltres__mwp_store_info') }} msi on t.store_id = msi.store_id
left join {{ ref('operations_grouping_plans') }} p ON p.plan = msi.plan