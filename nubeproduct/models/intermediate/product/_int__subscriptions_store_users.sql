with 
orders as (
    select
        completed_at
        ,id as order_id
        ,store_id
        ,customer_id
        ,contact_name
    from {{ source('stg_orders', 'mwp_orders') }} o
    where o.completed_at >= date_add(MONTH, -2, date_trunc('MONTH', current_date()))
        and contact_name not in ('Não informado', 'No informado')
        and currency = 'BRL'
),
product_orders as (
    select
        p.order_id
        ,product_id
        ,name_i18n as product_name
        ,quantity as total_quantity
        ,price
        ,(quantity * price) as total_ammount
    from {{ source('stg_orders', 'mwp_order_products') }} p
    inner join orders o
        on p.order_id = o.order_id
    where created_at >= date_add(MONTH, -2, date_trunc('MONTH', current_date()))
        and name_i18n is not null
),
product_orders_final as (
    select
        order_id
        ,product_id
        ,max(product_name) as product_name
        ,sum(total_quantity) as total_quantity
        ,sum(total_ammount) as total_ammount
        ,avg(price) as avg_price
    from product_orders
    group by 1,2
),
last_product_price as (
    select
        product_id
        ,price
        ,ROW_NUMBER() OVER (
            PARTITION BY product_id
            ORDER BY order_id DESC
            ) AS rn
    from product_orders
),
order_users as (
    select
        date(o.completed_at) as registered_date
        ,o.order_id
        ,o.store_id
        ,s.domain as store_name
        ,s.vertical_name
        ,s.created_at as store_created_at
        ,s.country_name
        ,o.customer_id
        ,o.contact_name
        ,p.product_id
        ,p.product_name
        ,p.total_ammount
        ,p.total_quantity
        ,lag(date(o.completed_at)) over (partition by o.store_id, o.customer_id, p.product_id order by date(o.completed_at) asc) as last_purchase_same_product
    from orders o
    inner join {{ ref('company_metrics_merchant_info') }} s
      on o.store_id = s.store_id
    inner join product_orders_final p
      on o.order_id = p.order_id
    where s.country_code = 'BR'
),
aux as (
    select
        registered_date
        ,order_id
        ,store_id
        ,vertical_name
        ,country_name
        ,store_name
        ,customer_id
        ,contact_name
        ,product_id
        ,product_name
        ,date_diff(DAY, last_purchase_same_product, registered_date) as days_since_last_purchase_same_product
    from order_users
)
select 
    o.store_id
    ,o.store_name
    ,o.vertical_name
    ,o.country_name
    ,o.customer_id
    ,o.contact_name
    ,o.product_id
    ,o.product_name
    ,avg(pof.avg_price) as avg_product_price
    ,max(case when lpp.rn = 1 then lpp.price end) as last_price
    ,count(distinct o.order_id) as total_orders
    ,avg(coalesce(o.days_since_last_purchase_same_product,1)) as avg_order_frequency
from aux o
inner join product_orders_final pof
    on o.order_id = pof.order_id 
    and o.product_id = pof.product_id
left join last_product_price lpp
    on o.product_id = lpp.product_id
group by 1,2,3,4,5,6,7,8
having avg_order_frequency >= 10
    and total_orders >= 5
