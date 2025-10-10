-- Consolidated store activity and NuvemPago related fields
with
    active as (select store_id from {{ ref("hubspot_active_stores") }}),

    url_stats as (
        select
            store_id,
            'https://stats.tiendanube.com/store/profile?store_id='
            || store_id as url_stats
        from active
    ),

    gmv as (
        select gmv_data.store_id, gmv_data.gmv
        from
            (
                select store_id, sum(gmv_usd_monthly) as gmv
                from {{ ref("company_metrics_gmv_and_segments") }}
                where datemonth >= date_format(date_sub(current_date(), 30), 'yyyyMM')
                group by store_id
            ) gmv_data
    ),

    np_trx as (
        select np_data.store_id, np_data.np_trx_last_30
        from
            (
                select store_id, count(distinct order_id) as np_trx_last_30
                from {{ source("stg_orders", "mwp_orders") }}
                where
                    completed_at is not null
                    and status != 'cancelled'
                    and payment_status = 'paid'
                    and gateway = 'app_2462'
                    and completed_at >= date_sub(current_date(), 30)
                group by store_id
            ) np_data
    ),

    np_kyc as (
        select kyc.store_id, kyc.np_kyc_rejected
        from
            (
                select distinct related_id as store_id, true as np_kyc_rejected
                from {{ source("int_moltres", "mwp_tags") }}
                where type = 'store' and tag = 'nuvempagoKYCRejected'
            ) kyc
    ),

    np_risk as (
        select risk.store_id, risk.np_clearsale_risk
        from
            (
                select distinct related_id as store_id, true as np_clearsale_risk
                from {{ source("int_moltres", "mwp_tags") }}
                where type = 'store' and tag = 'NuvemPagoRisk'
            ) risk
    ),

    np_document as (
        select store_id, doc_number as np_document
        from {{ ref("marketing_merchant_info_refined") }}
    )

select
    a.store_id,
    u.url_stats,
    coalesce(g.gmv, 0) as gmv,
    coalesce(t.np_trx_last_30, 0) as np_trx_last_30,
    coalesce(k.np_kyc_rejected, false) as np_kyc_rejected,
    coalesce(r.np_clearsale_risk, false) as np_clearsale_risk,
    d.np_document
from active a
left join url_stats u on u.store_id = a.store_id
left join gmv g on g.store_id = a.store_id
left join np_trx t on t.store_id = a.store_id
left join np_kyc k on k.store_id = a.store_id
left join np_risk r on r.store_id = a.store_id
left join np_document d on d.store_id = a.store_id
