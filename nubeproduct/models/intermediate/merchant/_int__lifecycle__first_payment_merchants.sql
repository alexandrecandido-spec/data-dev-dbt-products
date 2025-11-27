WITH store_info AS (
    SELECT
        store_id,
        country as store_country,
        cast(created_at as date) as store_created_at,
        cast(first_payment as date) as store_first_payment,
        first_payment as first_payment_timestamp
    FROM {{ ref('merchant__attributes__store_info__ref') }}
    WHERE state != 4
    AND first_payment is not null
),
contracts AS (
    SELECT
        store_id,
        created_at_contract,
        plan_id AS store_plan_id,
        deleted_contract
    FROM {{ ref('s__contracts__store_contracts__scd') }}
    WHERE contract_type NOT IN ('free','freemium','pre-churn','partner-test','pre-churn-lead','free-days','trial','url-free-days','test')
    OR contract_type IS NULL
),
contracts_latest_before_payment AS (
    SELECT
        c.store_id,
        c.created_at_contract,
        c.store_plan_id,
        c.deleted_contract,
        row_number() over (partition by c.store_id order by c.created_at_contract desc) as rn_latest
    FROM contracts c
    INNER JOIN store_info s ON c.store_id = s.store_id AND c.created_at_contract <= s.store_first_payment
),

first_payments AS (
    SELECT
        s.store_id,
        s.store_country,
        s.store_created_at,
        s.store_first_payment,
        c.store_plan_id as store_plan_id,
        CASE WHEN c.deleted_contract = true THEN TRUE ELSE FALSE END AS deleted_contract,
        s.first_payment_timestamp
    FROM store_info s
    LEFT JOIN contracts_latest_before_payment c ON s.store_id = c.store_id AND c.rn_latest = 1
)

SELECT
fp.store_id,
fp.store_country,
fp.store_created_at,
fp.store_first_payment,
fp.store_plan_id,
fp.deleted_contract,
fp.first_payment_timestamp
FROM first_payments fp