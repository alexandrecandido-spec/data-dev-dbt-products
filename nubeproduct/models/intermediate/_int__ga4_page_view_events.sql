WITH analytics_events AS (
    SELECT *
    FROM {{ ref('stg_marketing__ga4_analytics_events') }}
    WHERE source in (
            'inst-br',
            'inst-ar',
            'inst-mx',
            'inst-co',
            'inst-cl'
          ) -- GA4 property to get the data from, this is [GA4] Nuvemshop property	
          and event_name = 'page_view' -- all data here refers to page_view events, so filter for this event only	
)

SELECT -- calculates values for landing page (first page viewed per session), page (any page visited) and last click per session (source, medium, campaign), it uses previous data from a subquery that unnests the values from the main table (it hast json structure)	
    u_user_pseudo_id,
    unique_session,
    country,
    device_category, -- device used in a session, may have different categories for same session or for different sessions of the same user	
    event_date, -- date when the event happened	
    event_timestamp, -- will be useful to concatenate this with unique session id to obtain a unique click id, for page views calculations	
    env, --identifies the mkt team / area associated to the visited page, it is a tag in GA4	
    event_page, -- all visited pages	
    FIRST_VALUE(event_page) IGNORE NULLS OVER (
        PARTITION BY
          unique_session
        ORDER BY
          event_timestamp 
    ) as landing_page, -- first page viewed per session	
    LAST_VALUE(event_source) IGNORE NULLS OVER (
        PARTITION BY
          unique_session
        ORDER BY
          event_timestamp
    ) as last_source, -- last not null source value per session	
    LAST_VALUE(event_medium) IGNORE NULLS OVER (
        PARTITION BY
          unique_session
        ORDER BY
          event_timestamp
      ) as last_medium, -- last not null medium value per session	
    LAST_VALUE(event_campaign) IGNORE NULLS OVER (
        PARTITION BY
          unique_session
        ORDER BY
          event_timestamp
    ) as last_campaign
FROM analytics_events