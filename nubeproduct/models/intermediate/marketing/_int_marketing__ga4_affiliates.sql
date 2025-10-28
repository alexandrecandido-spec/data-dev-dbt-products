SELECT
    event_date,
    user_pseudo_id,
    unique_session,
    {{ marketing_country_ga4('source', 'landing_page', 'country') }} AS country,
    {{ marketing_partner_code_ga4('page') }} AS partner_code,
    source,
    landing_page,
    page,
    event_source,
    event_medium,
    event_campaign,
    event_content,
    event_term,
    sys_audit_updated_on
FROM {{ ref('marketing__general__ga4_all_pageviews__event') }}
WHERE page LIKE '%partners/%'