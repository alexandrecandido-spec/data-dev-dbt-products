SELECT msi.store_id, mss.in_portfolio, current_timestamp
 FROM (select distinct store_id from {{ ref('moltres__mwp_store_info') }}) msi 
left join {{ ref('midmarket_success_stores') }}  mss on msi.store_id = mss.store_id and mss.in_portfolio=true