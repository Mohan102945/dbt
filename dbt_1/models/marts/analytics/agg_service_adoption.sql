{{
    config(
        materialized='table',
        description='Service adoption rates and churn rate for each service type. Reveals which services correlate with retention.'
    )
}}

with customers as (

    select * from {{ ref('dim_customers') }}

),

service_flags as (

    select
        customer_id,
        has_churned,
        monthly_charges,

        unnest(array[
            'phone_service',
            'multiple_lines',
            'internet_service',
            'online_security',
            'online_backup',
            'device_protection',
            'tech_support',
            'streaming_tv',
            'streaming_movies'
        ])                                                  as service_name,

        unnest(array[
            has_phone_service::int,
            has_multiple_lines::int,
            has_internet_service::int,
            coalesce(has_online_security::int, 0),
            coalesce(has_online_backup::int, 0),
            coalesce(has_device_protection::int, 0),
            coalesce(has_tech_support::int, 0),
            coalesce(has_streaming_tv::int, 0),
            coalesce(has_streaming_movies::int, 0)
        ])                                                  as has_service

    from customers

),

adoption_stats as (

    select
        service_name,

        -- Adoption
        count(*)                                            as total_customers,
        sum(has_service)                                    as customers_with_service,
        round(sum(has_service)::numeric / count(*) * 100, 2)
                                                            as adoption_rate_pct,

        -- Churn comparison: subscribers vs non-subscribers
        round(
            sum(case when has_service = 1 and has_churned then 1 else 0 end)::numeric
            / nullif(sum(has_service), 0) * 100, 2
        )                                                   as churn_rate_with_service_pct,
        round(
            sum(case when has_service = 0 and has_churned then 1 else 0 end)::numeric
            / nullif(sum(1 - has_service), 0) * 100, 2
        )                                                   as churn_rate_without_service_pct,

        -- Revenue
        round(avg(case when has_service = 1 then monthly_charges end), 2)
                                                            as avg_monthly_charges_with_service,
        round(avg(case when has_service = 0 then monthly_charges end), 2)
                                                            as avg_monthly_charges_without_service

    from service_flags
    group by service_name

)

select
    service_name,
    total_customers,
    customers_with_service,
    adoption_rate_pct,
    churn_rate_with_service_pct,
    churn_rate_without_service_pct,
    -- Protective effect: negative = service reduces churn
    round(
        churn_rate_with_service_pct - churn_rate_without_service_pct,
        2
    )                                                       as churn_rate_delta_pct,
    avg_monthly_charges_with_service,
    avg_monthly_charges_without_service,
    current_timestamp                                       as dbt_updated_at
from adoption_stats
order by churn_rate_delta_pct asc -- most productive services first
