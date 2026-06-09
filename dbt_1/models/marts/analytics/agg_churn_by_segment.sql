{{
    config(
        materialized='table',
        description='Pre-aggregated churn metrics across key business segments. Drives executive dashboards and trend monitoring.'
    )
}}

with customers as (

    select * from {{ ref('dim_customers') }}

),

-- By Contract Type --
contract_agg as (

    select
        'contract_type'                         as segment_dimension,
        contract_type                           as segment_value,
        count(*)                                as total_customers,
        sum(case when has_churned then 1 end)   as churned_customers,
        round(
            sum(case when has_churned then 1 end)::numeric
            / nullif(count(*), 0) * 100, 2
        )                                       as churn_rate_pct,
        round(avg(monthly_charges), 2)          as avg_monthly_charges,
        round(avg(tenure_months), 1)            as avg_tenure_months,
        round(avg(total_services_subscribed), 2)as avg_services
    from customers
    group by contract_type

),

-- By Tenure Segment --
tenure_agg as (

    select
        'tenure_segment'                        as segment_dimension,
        tenure_segment                          as segment_value,
        count(*)                                as total_customers,
        sum(case when has_churned then 1 end)   as churned_customers,
        round(
            sum(case when has_churned then 1 end)::numeric
            / nullif(count(*), 0) * 100, 2
        )                                       as churn_rate_pct,
        round(avg(monthly_charges), 2)          as avg_monthly_charges,
        round(avg(tenure_months), 1)            as avg_tenure_months,
        round(avg(total_services_subscribed), 2)as avg_services
    from customers
    group by tenure_segment

),

-- By Internet Service --
internet_agg as (

    select
        'internet_service_type'                 as segment_dimension,
        coalesce(internet_service_type, 'none') as segment_value,
        count(*)                                as total_customers,
        sum(case when has_churned then 1 end)   as churned_customers,
        round(
            sum(case when has_churned then 1 end)::numeric
            / nullif(count(*), 0) * 100, 2
        )                                       as churn_rate_pct,
        round(avg(monthly_charges), 2)          as avg_monthly_charges,
        round(avg(tenure_months), 1)            as avg_tenure_months,
        round(avg(total_services_subscribed), 2)as avg_services
    from customers
    group by internet_service_type

),

-- By Monthly Charges Tier --
charges_agg as (

    select
        'monthly_charges_tier'                  as segment_dimension,
        monthly_charges_tier                    as segment_value,
        count(*)                                as total_customers,
        sum(case when has_churned then 1 end)   as churned_customers,
        round(
            sum(case when has_churned then 1 end)::numeric
            / nullif(count(*), 0) * 100, 2
        )                                       as churn_rate_pct,
        round(avg(monthly_charges), 2)          as avg_monthly_charges,
        round(avg(tenure_months), 1)            as avg_tenure_months,
        round(avg(total_services_subscribed), 2)as avg_services
    from customers
    group by monthly_charges_tier

),

-- By Payment Method --
payment_agg as (

    select
        'payment_method'                        as segment_dimension,
        payment_method                          as segment_value,
        count(*)                                as total_customers,
        sum(case when has_churned then 1 end)   as churned_customers,
        round(
            sum(case when has_churned then 1 end)::numeric
            / nullif(count(*), 0) * 100, 2
        )                                       as churn_rate_pct,
        round(avg(monthly_charges), 2)          as avg_monthly_charges,
        round(avg(tenure_months), 1)            as avg_tenure_months,
        round(avg(total_services_subscribed), 2)as avg_services
    from customers
    group by payment_method

),

-- By Churn Risk Label --
risk_agg as (

    select
        'churn_risk_label'                      as segment_dimension,
        churn_risk_label                        as segment_value,
        count(*)                                as total_customers,
        sum(case when has_churned then 1 end)   as churned_customers,
        round(
            sum(case when has_churned then 1 end)::numeric
            / nullif(count(*), 0) * 100, 2
        )                                       as churn_rate_pct,
        round(avg(monthly_charges), 2)          as avg_monthly_charges,
        round(avg(tenure_months), 1)            as avg_tenure_months,
        round(avg(total_services_subscribed), 2)as avg_services
    from customers
    group by churn_risk_label

),

unioned as (

    select * from contract_agg
    union all
    select * from tenure_agg
    union all
    select * from internet_agg
    union all
    select * from charges_agg
    union all
    select * from payment_agg
    union all
    select * from risk_agg

)

select
    {{ dbt_utils.generate_surrogate_key(['segment_dimension', 'segment_value']) }} as segment_sk,
    segment_dimension,
    segment_value,
    total_customers,
    churned_customers,
    total_customers - churned_customers  as retained_customers,
    churn_rate_pct,
    100 - churn_rate_pct                 as retention_rate_pct,
    avg_monthly_charges,
    avg_tenure_months,
    avg_services,
    current_timestamp                    as dbt_updated_at
from unioned
order by segment_dimension, churn_rate_pct desc