-- Owner: Guille De Felice

{{
    config(
        materialized='incremental',
        unique_key=['date_from', 'store_id'],
        incremental_strategy='append',
        on_schema_change='fail',
        tags=['monthly-4th-12pm']
    )
}}

SELECT 
    mbr.*,
    si.domain as store_name,
    CAST(si.churned_at AS DATE) as churned_at, 
    CAST(si.first_payment AS DATE) as first_payment,
    gp.lead_source,
    gp.deal_tags,
    gp.gmv_potencial,
    gp.data_go_live,
    gp.onboarding_type,
    gp.createdate,
    gas.orders_on_platform_monthly as orders,
    gas.gmv_local_currency_on_platform_monthly as gmv_local_currency,
    ROUND(gas.gmv_usd_on_platform_monthly, 2) as gmv_usd,
    t.gmv_local_currency_on_platform_90d as gmv_local_currency_90d,
    t.gmv_usd_on_platform_90d as gmv_usd_90d,
    t.gmv_tier,
    s.sessions,
    s.previous_sessions,
    i.calls,
    i.emails,
    i.meetings,
    i.tasks,
    i.whatsapp,
    c.contract_end_date,
    'monthly' as periodicity

FROM 
    {{ ref('midmarket_monthly_business_review') }} mbr
    LEFT JOIN {{ ref('moltres__mwp_store_info') }} si
        on mbr.store_id = si.store_id
    LEFT JOIN {{ ref('_int_midmarket_wbr_mbr__general_properties') }} gp
        on mbr.store_id = gp.store_id
    LEFT JOIN {{ ref('company_metrics_gmv_and_segments') }} gas
        on mbr.store_id = gas.store_id
        and mbr.date_to = gas.datemonth
    LEFT JOIN {{ ref('_int_midmarket_wbr_mbr__tier') }} t
        on mbr.store_id = t.store_id
        and mbr.date_to = t.datemonth
    LEFT JOIN {{ ref('operations_grouping_sessions') }} s
        on mbr.store_id = s.store_id
        and mbr.date_from = s.date_from
        and s.periodicity = 'monthly'
    LEFT JOIN {{ ref('midmarket_grouping_interactions') }} i
        on mbr.store_id = i.store_id
        and mbr.date_from = i.date_from
        and i.periodicity = 'monthly'
    LEFT JOIN {{ ref('_int_midmarket_wbr_mbr__companies') }} c
        on mbr.store_id = c.store_id

{% if is_incremental() %}
WHERE
    mbr.date_from > (
        SELECT max(date_from) 
        FROM {{ this }} 
        )
{% endif %}