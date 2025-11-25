{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = 'unique_id',
    partition_by = 'registered_date',
    on_schema_change = 'fail',
    tags = ['daily-8am'],
    pre_hook = [
        """
        {% if is_incremental() %}
            DELETE FROM {{ this }} WHERE registered_date >= date_trunc('day', current_date())
        {% endif %}
        """
    ]
) }}

with app_daily_installs as (
    SELECT
        registered_date
        ,app_id
        ,partner_id
        ,partner_name
        ,app_name
        ,app_country
        ,store_country
        ,category
        ,creation_date
        ,deleted_date
        ,app_published_date
        ,is_app_published
        ,is_new_app
        ,is_new_published_app
        ,is_churned_app
        ,is_active_app
        ,is_public_active_app
        ,plan_name
        ,current_segment
        ,daily_installs
        ,daily_uninstalls
        ,active_stores
    from {{ ref('_int_platform_app_daily_installs') }}
)
SELECT distinct
    concat(cast(registered_date as string), '_'
            , cast(app_id as string), '_'
            , cast(coalesce(app_country,'no_country') as string), '_'
            , cast(coalesce(store_country,'no_country') as string), '_'
            , cast(coalesce(plan_name,'no_plan') as string), '_'
            , cast(coalesce(current_segment,'no_segment') as string), '_'
        ) as unique_id
    ,a.*
    ,current_timestamp AS sys_audit_created_on
    ,'data-dev-dbt-products' AS sys_audit_created_by
    ,current_timestamp AS sys_audit_updated_on
    ,'data-dev-dbt-products' AS sys_audit_updated_by
    from app_daily_installs a
    {% if is_incremental() %}
        where a.registered_date >= date_trunc('day', current_date())
    {% endif %}