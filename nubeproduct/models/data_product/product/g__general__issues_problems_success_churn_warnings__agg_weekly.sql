-- depends_on: {{ ref('orders__mwp_orders') }}
{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['dates','country','origen','cause'],
        on_schema_change='fail',
        tags=["daily-8am"]
    )
}}
WITH source AS (
select
w.dates,
w.country,
w.origen,
w.cause,
w.merchants
from {{ ref('_int__issues_and_problems_success_warnings') }} w
    {% if is_incremental() %}
        and w.dates >= DATE_SUB( (SELECT COALESCE(MAX(dates), DATE('1900-01-01')) FROM {{ this }}), 15 )
    {% endif %}

UNION

select
c.dates,
c.country,
c.origen,
c.cause,
c.merchants
from  {{ ref('_int__issues_and_problems_success_churn') }} c
 {% if is_incremental() %}
        and c.dates >= DATE_SUB( (SELECT COALESCE(MAX(dates), DATE('1900-01-01')) FROM {{ this }}), 15 )
    {% endif %}
),
    existing_data AS (
        {{ get_existing_data(this, ['dates','country','origen','cause',
        'sys_audit_created_on', 'sys_audit_created_by', 'sys_audit_updated_on', 'sys_audit_updated_by']) }}
    )

select
    s.dates,
    s.country,
    s.origen,
    s.cause,
    s.merchants,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
from source s
left join existing_data e on 
    s.dates = e.dates and
    s.country = e.country and
    s.origen = e.origen and
    s.cause = e.cause
