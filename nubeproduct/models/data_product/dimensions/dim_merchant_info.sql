
{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['store_id'],
    on_schema_change='fail',
    tags=['daily-8_30am']
) }}

WITH 

 existing_data AS ({{ get_existing_data(this, ['store_id', 'sys_audit_created_on', 'sys_audit_created_by']) }})

,store_id_tbp AS 
(
	
	SELECT DISTINCT store_id FROM 
	(

    SELECT store_id
    FROM {{ ref('moltres__mwp_store_info') }}
    {% if is_incremental() %}
    WHERE sys_audit_updated_on > (SELECT MAX(sys_audit_updated_on) FROM {{ this }})
    {% endif %}

    UNION ALL
    SELECT store_id
    FROM {{ ref('_int_dim_merchant_info__location_by_zipcode') }}
    {% if is_incremental() %}
    WHERE sys_audit_updated_on > (SELECT MAX(sys_audit_updated_on) FROM {{ this }})
    {% endif %}

    UNION ALL
    
    SELECT store_id
    FROM {{ ref('_int_dim_merchant_info__segment') }}
    {% if is_incremental() %}
    WHERE sys_audit_updated_on > (SELECT MAX(sys_audit_updated_on) FROM {{ this }})
    {% endif %}

    UNION ALL
    
    SELECT store_id
    FROM {{ ref('_int_dim_merchant_info__vertifier_and_vertical') }}
    {% if is_incremental() %}
    WHERE sys_audit_updated_on > (SELECT MAX(sys_audit_updated_on) FROM {{ this }})
    {% endif %}

    UNION ALL

    SELECT store_id
    FROM {{ ref('_int_dim_merchant_info__business_size') }}
    {% if is_incremental() %}
    WHERE sys_audit_updated_on > (SELECT MAX(sys_audit_updated_on) FROM {{ this }})
    {% endif %}
    
    ) x
)

,tb_inc AS
(
SELECT a.store_id, DATE(a.created_at) AS created_at, a.domain, a.country as country_code, a.plan as plan_id_nk
FROM   {{ ref('moltres__mwp_store_info') }} AS a
INNER  JOIN store_id_tbp AS b ON a.store_id = b.store_id
)

,merchant_info AS 
(
SELECT 
a.store_id,
a.created_at,
COALESCE(b.country_id, -1) AS country_id,
COALESCE(c.country_id, -1) AS base_country_id,
COALESCE(c.region_id,  -1) AS base_region_id,
COALESCE(c.state_id,   -1) AS base_state_id,
COALESCE(c.city_id,    -1) AS base_city_id,
COALESCE(d.current_segment_id, -1) AS current_segment_id,
d.current_segment_date_id,
COALESCE(d.max_segment_id, -1) AS max_segment_id,
d.max_segment_date_id,
COALESCE(e.vertical_id, -1) AS vertical_id,
COALESCE(f.business_size_id, -1) AS business_size_id,
CASE WHEN g.group_id IN (20, 21) THEN -1 ELSE COALESCE(g.group_id, -1) END AS group_id,
a.domain
FROM tb_inc AS a
LEFT JOIN {{ ref('dim_location_country') }} b ON b.country_code = a.country_code
LEFT JOIN {{ ref('_int_dim_merchant_info__location_by_zipcode') }} c ON a.store_id = c.store_id
LEFT JOIN {{ ref('_int_dim_merchant_info__segment') }} d ON a.store_id = d.store_id
LEFT JOIN {{ ref('_int_dim_merchant_info__vertifier_and_vertical') }} e ON a.store_id = e.store_id
LEFT JOIN {{ ref('_int_dim_merchant_info__business_size') }} f ON a.store_id = f.store_id
LEFT JOIN {{ ref('dim_group_plan') }} g ON array_contains(g.plan_id_nk, a.plan_id_nk)
)

SELECT
a.store_id,
a.created_at,
a.country_id,
a.base_country_id,
a.base_region_id,
a.base_state_id,
a.base_city_id,
a.current_segment_id,
a.current_segment_date_id,
a.max_segment_id,
a.max_segment_date_id,
a.vertical_id,
a.business_size_id,
a.group_id,
a.domain,
COALESCE(b.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
COALESCE(b.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
current_timestamp AS sys_audit_updated_on,
'data-dev-dbt-products' AS sys_audit_updated_by
FROM merchant_info a
LEFT JOIN existing_data b ON a.store_id = b.store_id