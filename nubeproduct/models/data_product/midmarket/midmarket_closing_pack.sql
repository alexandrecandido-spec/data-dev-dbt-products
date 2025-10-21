{{ config(
    materialized='table',
    tags=['operations','daily-6am']
) }}

select * from {{ ref('_int_midmarket_closing_pack_merchants') }}
union all
select * from {{ ref('_int_midmarket_closing_pack_warnings') }}
union all
select * from {{ ref('_int_midmarket_closing_pack_unknowns') }}
union all
select * from {{ ref('_int_midmarket_closing_pack_out_of_portfolio') }}
union all
select * from {{ ref('_int_midmarket_closing_pack_churns') }}