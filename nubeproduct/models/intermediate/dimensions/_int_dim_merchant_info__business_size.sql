SELECT a.store_id, b.business_size_id, a.sys_audit_updated_on
FROM {{ source('dp_moltres','mwp_store_settings') }} a
INNER JOIN {{ ref('dim_business_size') }} b ON a.business_size = b.business_size_name