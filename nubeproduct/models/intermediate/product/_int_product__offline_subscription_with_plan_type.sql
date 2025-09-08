-- gets plans information
WITH base_subscriptions AS (
SELECT
    subscription_id
    , store_id
    , plan_id
    , start_date
    , end_date
    , cpt
    , sys_audit_updated_on AS subscription_updated_on
FROM 
    {{ ref('product__offline_plan_subscriptions') }}
)

-- gets valid stores
, filtered_stores AS (
SELECT
    store_id
    , sys_audit_updated_on AS store_updated_on
FROM 
    {{ ref('moltres__mwp_store_info') }}
WHERE 
    is_store_blocked = FALSE
)

-- filters valid stores and creates plan_type
, subscriptions_with_plan_type AS (
SELECT
    bs.subscription_id
    , bs.store_id
    , bs.start_date
    , bs.end_date
    , bs.cpt
    , LOWER(p.category) AS plan_name
    , CASE WHEN LOWER(p.category) LIKE '%trial%' THEN 'trial' ELSE 'regular' END AS plan_type
    , bs.subscription_updated_on
    , fs.store_updated_on
FROM 
    base_subscriptions AS bs
INNER JOIN 
    filtered_stores AS fs
    ON bs.store_id = fs.store_id
LEFT JOIN 
    offline.plans AS p
    ON bs.plan_id = p.id
)

-- final info
SELECT 
    *
FROM 
    subscriptions_with_plan_type
