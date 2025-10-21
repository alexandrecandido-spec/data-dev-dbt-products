{{
    config(
        materialized='incremental',
        unique_key=['store_id'],
        on_schema_change='fail',
        tags=['dimensions','daily-5am']
    )
}}

WITH
 sp AS 
(
SELECT
 CAST(storeid AS bigint) AS store_id
,address.country.code    AS country_code
,address.province.code   AS state_code
,address.zipcode         AS zipcode
,sys_audit_updated_on
FROM  {{ source('stg_shipping','locations') }}
WHERE address IS NOT NULL 
AND   chosenasdefaultat IS NOT NULL 
AND   deletedat IS NULL 
AND   isdraft = false
)
,zip AS
(
select zipcode, city_id, 'AR' AS country_code FROM {{ source('stg_moltres','mwp_zipcodes_ar') }} UNION ALL
select zipcode, city_id, 'MX' AS country_code FROM {{ source('stg_moltres','mwp_zipcodes_mx') }} UNION ALL
select cep as zipcode, CAST(city_id AS bigint) AS city_id, 'BR' AS country_code FROM 
(
select cep, city_id, ROW_NUMBER() OVER(PARTITION BY cep ORDER BY sys_audit_updated_on DESC) AS rnk FROM {{ source('stg_moltres','ceps') }}
) WHERE rnk = 1
)
,loc AS 
(
SELECT 
 s.store_id
,s.country_code
,COALESCE(s.state_code,'Not Informed') AS state_code
,COALESCE(z.city_id,-1) AS city_id_nk
,s.sys_audit_updated_on
FROM  sp s
LEFT JOIN zip z ON s.zipcode = z.zipcode AND s.country_code= z.country_code
WHERE 
    {% if is_incremental() %}
    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    s.sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} )
    {% else %}
        1 = 1 -- this will always be true if not incremental
    {% endif %}
),
existing_data AS (
    {{ get_existing_data(this, ['store_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

select
 a.store_id
,COALESCE(b.country_id,-1) AS country_id
,COALESCE(c.state_id, d.state_id,-1) AS state_id
,COALESCE(c.region_id, d.region_id, -1) AS region_id
,COALESCE(d.city_id,   -1) AS city_id
,COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on
,COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by
,current_timestamp AS sys_audit_updated_on
,'data-dev-dbt-products' AS sys_audit_updated_by
from loc AS a
LEFT JOIN existing_data e ON a.store_id = e.store_id
LEFT JOIN {{ ref('dimension__attributes__location_country__ref') }} AS b ON b.country_code = a.country_code
LEFT JOIN {{ ref('dimension__attributes__location_state__ref') }}   AS c ON c.country_id = b.country_id AND c.state_code = a.state_code
LEFT JOIN {{ ref('dimension__attributes__location_city__ref') }}    AS d ON d.country_id = b.country_id AND d.city_id_nk = a.city_id_nk