-- Store status based on PHP logic (simplified)
with
    plan_info as (
        select
            msi.store_id,
            msi.state,
            msi.churned_at,
            msi.first_payment,
            msi.partnership_type,
            msi.disabled,
            msi.plan as plan_id,
            coalesce(pc.monthly, 0) as monthly
        from {{ ref("moltres__mwp_store_info") }} msi
        left join
            {{ source("int_moltres", "mwp_plans_countries") }} pc on msi.plan = pc.id
    )

select
    store_id,
    case
        -- isTest(): state == STATE_TEST (4)
        when state = 4
        then 'test'

        -- isChurn(): state == STATE_STORE_DOWN (3)
        when state = 3
        then
            case
                when first_payment is not null
                then 'churn'
                when partnership_type = 'store_development' and churned_at is null
                then 'hand-off'
                else 'non-activation'
            end

        -- disabled: $store->disabled (timestamp when disabled, null when not disabled)
        when disabled is not null
        then 'cancel'

        -- plan->is_free(): monthly == 0
        when monthly = 0
        then 'free'

        -- isDevelopment(): state == STATE_DEVELOPMENT (5)
        when state = 5
        then 'development'

        -- isTrial(): first_payment is null (states 3,4,5 already checked above, only
        -- 0,1,2 remain)
        when first_payment is null
        then 'trial'

        -- isPaying(): everything else that's not churn, trial, free, development
        else 'paying'
    end as status
from plan_info
