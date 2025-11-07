{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['store_id'],
    on_schema_change = 'fail',
    tags = ['daily-10am-10pm'],
    post_hook=[
            "DELETE FROM {{ this }}
                    WHERE store_id IN (
                        SELECT store_id
                        FROM {{ ref('merchant__attributes__store_info__ref') }}
                        WHERE state = 4 
            )"
            ]
) }}

WITH existing_data AS (
  {{ get_existing_data(this, ['store_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),
source_data AS (
    SELECT 
        main_source.store_id,
        main_source.partner_id,

        main_source.tag_acquired_by,

        main_source.quality_lead_flag AS is_quality_lead,

        main_source.mkt_source_last_click,
        main_source.mkt_subteam_last_click,
        main_source.mkt_campaign_last_click,
        main_source.mkt_source_first_click,
        main_source.mkt_subteam_first_click,
        main_source.mkt_campaign_first_click,
        main_source.affiliate_owner AS mkt_source_partner_click,
        main_source.mkt_subteam_partner_click,
        main_source.mkt_campaign_partner_click,
        main_source.mkt_landing_page_domain_first_click,
        main_source.mkt_landing_page_domain_last_click,
        main_source.mkt_landing_page_path_first_click,
        main_source.mkt_landing_page_path_last_click,

        main_source.ql_profile,

        main_source.blocked_fraud_tag,

        main_source.change_timestamp
    FROM {{ ref('_int__acquisition__profile_store') }} AS main_source
    {% if is_incremental() %}
    WHERE main_source.change_timestamp > ( SELECT COALESCE(MAX(sys_audit_updated_on), DATE '1900-01-01') FROM {{ this }} )
    {% endif %}
)
SELECT 
    sd.* EXCEPT(sd.change_timestamp),
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM source_data sd
LEFT JOIN existing_data e
    ON sd.store_id = e.store_id