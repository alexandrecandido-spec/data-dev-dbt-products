WITH base AS (
    SELECT *
    FROM {{ ref('_int__affiliates_performance_metrics') }}
    WHERE partner_id IS NOT NULL
),

partners AS (
    SELECT
        partner_id,
        affiliate_tier,
        affiliate_classification,
        partner_utm_campaign,
        partner_utm_source,
        partner_utm_medium,
        partner_utm_content,
        mkt_exclusion,
        flag_partner_exception
    FROM {{ ref('s__general__partners_info__ref') }}
),

joined AS (
    SELECT
        md5(CONCAT(b.partner_id, b.country_code, b.date)) AS hash_partner_key,
        p.affiliate_tier,
        p.affiliate_classification,
        p.partner_utm_campaign,
        p.partner_utm_source,
        p.partner_utm_medium,
        p.partner_utm_content,
        p.mkt_exclusion,
        p.flag_partner_exception,
        b.*
    FROM base b
    LEFT JOIN partners p ON b.partner_id = p.partner_id 
)
SELECT
    *
FROM joined
