with
    store_tags as (
        select related_id as store_id, string_agg(tag, ', ') as tags_routing
        from {{ source("int_moltres", "mwp_tags") }}
        where
            type = 'store'
            and tag in (
                'partner-test',
                'customer-success-ar',
                'customer-success-br',
                'customer-success-mx',
                'sre-block-store-404',
                'sre-block-404-store',
                'block-storefront',
                'retencaonp-suporte-research',
                'retencaonp-suporte-pricing',
                'nuvempagoKYCRejected',
                'NuvemPagoRisk',
                'nuvem-envio-admin-blocking',
                'transaction-fee-blocking',
                'cloud-humans',
                'inside-sales-support-preference',
                'upmarket-support-escala',
                'cs-onboarding-mx',
                'PagoNubeRisk',
                'project-shiva'
            )
        group by related_id
    )

select store_id, tags_routing
from store_tags
