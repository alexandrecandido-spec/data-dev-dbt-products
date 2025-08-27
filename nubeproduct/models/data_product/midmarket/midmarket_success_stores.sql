-- Owner: Guille De Felice

{{ 
    config(
        materialized='table', 
        on_schema_change='fail',
        tags = ['weekly-monday-9am-monthly-1st-12pm']
    ) 
}}

with ranked_deals AS (
    SELECT 
        deal_id,
        store_id,
        case 
            when dealstage in ('Effective churn', 'Out of portfolio') then false 
            else true 
        end as in_portfolio,
        ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY createdate DESC) AS rn
    FROM {{ source("dp_third_party", "midmarket_hubspot_deals") }} d
        LEFT JOIN {{ source("dp_hubspot", "deals_archived") }} da
            ON d.deal_id = da.id
    WHERE 
        pipeline IN ('Success | BR', 'Success | AR', 'Success | MX')
        AND da.archived IS DISTINCT FROM true
)
SELECT 
    deal_id,
    store_id,
    in_portfolio,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by
FROM ranked_deals
WHERE 
    rn = 1
    and store_id > 0