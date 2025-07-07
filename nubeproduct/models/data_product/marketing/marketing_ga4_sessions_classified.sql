{{ config(
    materialized         = 'incremental',         
    incremental_strategy = 'merge',
    partition_by         = ['year_month_day_code'],   
    unique_key           = ['year_month_day_code','unique_session'],
    on_schema_change     = 'sync_all_columns',
    tags                 = ['daily-5am']
) }}

WITH src AS (

    SELECT
        date,
        CAST(date_format(date,'yyyyMMdd') AS int)  AS year_month_day_code,
        source_ga4_classification,
        original_user_country,
        env,
        landing_page,
        landing_page_type,
        last_source,
        last_medium,
        last_campaign,
        first_event_device,
        last_event_device,
        only_login_session,
        user_type,
        engage,
        utm_ad_id,
        user_pseudo_id,
        unique_session,
        trial,
        payment,
        session_duration_minutes,
        pageviews_per_session

    FROM {{ ref('_int_marketing__ga4_sessions_with_dimensions') }}

    WHERE
        {% if is_incremental() %}
              CAST(date_format(date,'yyyyMMdd') AS int)
                  >= CAST(date_format(date_sub(current_date(),3),'yyyyMMdd') AS int)
        {% else %}
              date >= DATE '2024-01-01'
        {% endif %}
)

SELECT
    src.*,

    CASE
        WHEN date <= DATE '2024-09-07' THEN
             CASE
                 WHEN source_ga4_classification = 'inst-br'
                      OR (source_ga4_classification NOT LIKE '%inst%'
                          AND landing_page LIKE '%nuvemshop%')
                 THEN 'BR'

                 WHEN source_ga4_classification = 'inst-ar' THEN 'AR'
                 WHEN source_ga4_classification = 'inst-mx' THEN 'MX'
                 WHEN source_ga4_classification = 'inst-co' THEN 'CO'
                 WHEN source_ga4_classification = 'inst-cl' THEN 'CL'

                 WHEN source_ga4_classification NOT LIKE '%inst%'
                      AND original_user_country = 'Argentina' THEN 'AR'
                 WHEN source_ga4_classification NOT LIKE '%inst%'
                      AND original_user_country = 'Mexico'    THEN 'MX'
                 WHEN source_ga4_classification NOT LIKE '%inst%'
                      AND original_user_country = 'Chile'     THEN 'CL'
                 WHEN source_ga4_classification NOT LIKE '%inst%'
                      AND original_user_country = 'Colombia'  THEN 'CO'

                 WHEN source_ga4_classification NOT LIKE '%inst%'
                      AND original_user_country NOT IN ('Brazil','Mexico',
                                                        'Argentina','Chile','Colombia')
                 THEN 'Other'

                 ELSE original_user_country
             END

        ELSE
             CASE
                 WHEN source_ga4_classification = 'inst-br'
                      OR landing_page LIKE '%nuvemshop%'              THEN 'BR'
                 WHEN original_user_country = 'Argentina'             THEN 'AR'
                 WHEN original_user_country = 'Mexico'                THEN 'MX'
                 WHEN original_user_country = 'Chile'                 THEN 'CL'
                 WHEN original_user_country = 'Colombia'              THEN 'CO'
                 WHEN original_user_country NOT IN ('Brazil','Mexico',
                                                    'Argentina','Chile','Colombia')
                 THEN 'Other'
                 ELSE original_user_country
             END
    END AS classified_country,
    current_timestamp()       AS sys_audit_created_on,
    'data-dev-dbt-products'   AS sys_audit_created_by,
    current_timestamp()       AS sys_audit_updated_on,
    'data-dev-dbt-products'   AS sys_audit_updated_by

FROM src
