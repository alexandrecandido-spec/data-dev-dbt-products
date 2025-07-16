{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['store_id'],
        on_schema_change='fail',
        tags=['daily-6am']
    )
}}

SELECT
 a.store_id
,a.created_at
,b.country_code
,b.country_name
,c.country_code AS base_country_code
,c.country_name AS base_country_name
,d.region_name  AS base_region_name
,e.state_name   AS base_state_name
,f.city_name    AS base_city_name
,g.segment_name AS current_segment_name
,a.current_segment_date_id
,h.segment_name AS max_segment_name
,a.max_segment_date_id
,i.vertical_name
,j.business_size_name
,k.group_name
,a.domain AS domain
FROM      {{ ref('dim_merchant_info') }}    a
LEFT JOIN {{ ref('dim_location_country') }} b ON b.country_id       = a.country_id
LEFT JOIN {{ ref('dim_location_country') }} c ON c.country_id       = a.base_country_id
LEFT JOIN {{ ref('dim_location_region') }}  d ON d.region_id        = a.base_region_id
LEFT JOIN {{ ref('dim_location_state') }}   e ON e.state_id         = a.base_state_id
LEFT JOIN {{ ref('dim_location_city') }}    f ON f.city_id          = a.base_city_id
LEFT JOIN {{ ref('dim_segment_type') }}     g ON g.segment_id       = a.current_segment_id
LEFT JOIN {{ ref('dim_segment_type') }}     h ON h.segment_id       = a.max_segment_id
LEFT JOIN {{ ref('dim_vertical_type') }}    i ON i.vertical_id      = a.vertical_id
LEFT JOIN {{ ref('dim_business_size') }}    j ON j.business_size_id = a.business_size_id
LEFT JOIN {{ ref('dim_group_plan') }}       k ON k.group_id         = a.group_id