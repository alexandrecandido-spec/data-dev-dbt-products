SELECT
  msi.country
, msi.created_at
, msi.device
, COALESCE(COUNT(DISTINCT CASE WHEN att.attribution_source = 'local_db' THEN att.store_id END),0) as stores_source_local_db
, COALESCE(COUNT(DISTINCT CASE WHEN att.attribution_source = 'amplitude' THEN att.store_id END),0) as stores_source_amplitude
, COALESCE(COUNT(DISTINCT CASE WHEN att.attribution_source = 'empty' THEN att.store_id END),0) as stores_source_empty
, COALESCE(COUNT(DISTINCT att.store_id),0) as stores_total
FROM {{source('int_attribution', 'store_attribution')}} att
INNER JOIN {{ ref('_int_marketing_store_info__get_quality_leads_info') }} msi ON att.store_id = msi.store_id
GROUP BY 1,2,3